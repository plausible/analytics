defmodule Plausible.Google.API do
  @moduledoc """
  API to Google services.
  """

  use Timex

  alias Plausible.Google.HTTP

  require Logger
  import Plausible.Stats.Base, only: [page_regex: 1]

  @search_console_scope URI.encode_www_form(
                          "email https://www.googleapis.com/auth/webmasters.readonly"
                        )
  @import_scope URI.encode_www_form("email https://www.googleapis.com/auth/analytics.readonly")

  @verified_permission_levels ["siteOwner", "siteFullUser", "siteRestrictedUser"]

  def search_console_authorize_url(site_id) do
    "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@search_console_scope}&state=" <>
      Jason.encode!([site_id, "search-console"])
  end

  def import_authorize_url(site_id) do
    "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@import_scope}&state=" <>
      Jason.encode!([site_id, "import"])
  end

  def fetch_access_token!(code) do
    HTTP.fetch_access_token!(code)
  end

  def list_properties_and_views(access_token) do
    with {:ok, properties} <- Plausible.Google.GA4.API.list_properties(access_token),
         {:ok, views} <- Plausible.Google.UA.API.list_views(access_token) do
      {:ok, properties ++ views}
    end
  end

  def get_property_or_view(access_token, property_or_view) do
    if property?(property_or_view) do
      Plausible.Google.GA4.API.get_property(access_token, property_or_view)
    else
      Plausible.Google.UA.API.get_view(access_token, property_or_view)
    end
  end

  def get_analytics_start_date(access_token, property_or_view) do
    if property?(property_or_view) do
      Plausible.Google.GA4.API.get_analytics_start_date(access_token, property_or_view)
    else
      Plausible.Google.UA.API.get_analytics_start_date(access_token, property_or_view)
    end
  end

  def get_analytics_end_date(access_token, property_or_view) do
    if property?(property_or_view) do
      Plausible.Google.GA4.API.get_analytics_end_date(access_token, property_or_view)
    else
      Plausible.Google.UA.API.get_analytics_end_date(access_token, property_or_view)
    end
  end

  def fetch_verified_properties(auth) do
    with {:ok, access_token} <- maybe_refresh_token(auth),
         {:ok, sites} <- Plausible.Google.HTTP.list_sites(access_token) do
      sites
      |> Map.get("siteEntry", [])
      |> Enum.filter(fn site -> site["permissionLevel"] in @verified_permission_levels end)
      |> Enum.map(fn site -> site["siteUrl"] end)
      |> Enum.map(fn url -> String.trim_trailing(url, "/") end)
      |> then(&{:ok, &1})
    end
  end

  def fetch_stats(site, %{filters: %{} = filters, date_range: date_range}, limit) do
    with site <- Plausible.Repo.preload(site, :google_auth),
         {:ok, access_token} <- maybe_refresh_token(site.google_auth),
         {:ok, search_console_filters} <-
           get_search_console_filters(site.google_auth.property, filters),
         {:ok, stats} <-
           HTTP.list_stats(
             access_token,
             site.google_auth.property,
             date_range,
             limit,
             search_console_filters
           ) do
      stats
      |> Map.get("rows", [])
      |> Enum.filter(fn row -> row["clicks"] > 0 end)
      |> Enum.map(fn row -> %{name: row["keys"], visitors: round(row["clicks"])} end)
      |> then(&{:ok, &1})
    else
      # Show empty report to user with message about not being able to get keyword data for this set of filters
      :bad_filters -> raise "FILTERS ARE BAD"
    end
  end

  def maybe_refresh_token(%Plausible.Site.GoogleAuth{} = auth) do
    with true <- needs_to_refresh_token?(auth.expires),
         {:ok, {new_access_token, expires_at}} <- do_refresh_token(auth.refresh_token),
         changeset <-
           Plausible.Site.GoogleAuth.changeset(auth, %{
             access_token: new_access_token,
             expires: expires_at
           }),
         {:ok, _google_auth} <- Plausible.Repo.update(changeset) do
      {:ok, new_access_token}
    else
      false -> {:ok, auth.access_token}
      {:error, cause} -> {:error, cause}
    end
  end

  def maybe_refresh_token({access_token, refresh_token, expires_at}) do
    with true <- needs_to_refresh_token?(expires_at),
         {:ok, {new_access_token, _expires_at}} <- do_refresh_token(refresh_token) do
      {:ok, new_access_token}
    else
      false -> {:ok, access_token}
      {:error, cause} -> {:error, cause}
    end
  end

  def property?(value), do: String.starts_with?(value, "properties/")

  defp do_refresh_token(refresh_token) do
    case HTTP.refresh_auth_token(refresh_token) do
      {:ok, %{"access_token" => new_access_token, "expires_in" => expires_in}} ->
        expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), expires_in)
        {:ok, {new_access_token, expires_at}}

      {:error, cause} ->
        {:error, cause}
    end
  end

  defp needs_to_refresh_token?(expires_at) when is_binary(expires_at) do
    expires_at
    |> NaiveDateTime.from_iso8601!()
    |> needs_to_refresh_token?()
  end

  defp needs_to_refresh_token?(%NaiveDateTime{} = expires_at) do
    thirty_seconds_ago = Timex.shift(Timex.now(), seconds: 30)
    Timex.before?(expires_at, thirty_seconds_ago)
  end

  defp get_search_console_filters(property, plausible_filters) do
    plausible_filters = Map.drop(plausible_filters, ["visit:source"])

    search_console_filters =
      Enum.reduce_while(plausible_filters, [], fn plausible_filter, search_console_filters ->
        case transform_filter(property, plausible_filter) do
          :err -> {:halt, :bad_filters}
          search_console_filter -> {:cont, [search_console_filter | search_console_filters]}
        end
      end)

    case search_console_filters do
      :bad_filters -> :bad_filters
      filters when is_list(filters) -> {:ok, [%{filters: filters}]}
    end
  end

  defp transform_filter(property, {"event:page", filter}) do
    transform_filter(property, {"visit:entry_page", filter})
  end

  defp transform_filter(property, {"visit:entry_page", {:is, page}}) when is_binary(page) do
    %{dimension: "page", expression: property_url(property, page)}
  end

  defp transform_filter(property, {"visit:entry_page", {:member, pages}}) when is_list(pages) do
    expression =
      Enum.map(pages, fn page -> property_url(property, Regex.escape(page)) end) |> Enum.join("|")

    %{dimension: "page", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(property, {"visit:entry_page", {:matches, page}}) when is_binary(page) do
    page = page_regex(property_url(property, page))
    %{dimension: "page", operator: "includingRegex", expression: page}
  end

  defp transform_filter(property, {"visit:entry_page", {:matches_member, pages}})
       when is_list(pages) do
    expression = Enum.map(pages, fn page -> page_regex(page) end) |> Enum.join("|")
    %{dimension: "page", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_property, {"visit:screen", {:is, device}}) when is_binary(device) do
    %{dimension: "device", expression: search_console_device(device)}
  end

  defp transform_filter(_property, {"visit:screen", {:is, device}}) when is_binary(device) do
    %{dimension: "device", expression: search_console_device(device)}
  end

  defp transform_filter(_property, {"visit:screen", {:member, devices}}) when is_list(devices) do
    expression = devices |> Enum.join("|")
    %{dimension: "device", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_property, {"visit:country", {:is, country}}) when is_binary(country) do
    %{dimension: "country", expression: search_console_country(country)}
  end

  defp transform_filter(_property, {"visit:country", {:member, countries}})
       when is_list(countries) do
    expression = Enum.map(countries, &search_console_country/1) |> Enum.join("|")
    %{dimension: "country", operator: "includingRegex", expression: expression}
  end

  defp transform_filter(_, filter) do
    IO.inspect(filter)
    :err
  end

  defp property_url("sc-domain:" <> domain, page), do: "https://" <> domain <> page
  defp property_url(url, page), do: url <> page

  defp search_console_device("Desktop"), do: "DESKTOP"
  defp search_console_device("Mobile"), do: "MOBILE"
  defp search_console_device("Tablet"), do: "TABLET"

  defp search_console_country(alpha_2) do
    country = Location.Country.get_country(alpha_2)
    country.alpha_3
  end

  defp client_id() do
    Keyword.fetch!(Application.get_env(:plausible, :google), :client_id)
  end

  defp redirect_uri() do
    PlausibleWeb.Endpoint.url() <> "/auth/google/callback"
  end
end
