defmodule Plausible.Google.API do
  @moduledoc """
  API to Google services.
  """

  alias Plausible.Google.HTTP
  alias Plausible.Google.SearchConsole
  alias Plausible.Stats.Query

  require Logger

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

  def list_properties(access_token) do
    Plausible.Google.GA4.API.list_properties(access_token)
  end

  def get_property(access_token, property) do
    Plausible.Google.GA4.API.get_property(access_token, property)
  end

  def get_analytics_start_date(access_token, property) do
    Plausible.Google.GA4.API.get_analytics_start_date(access_token, property)
  end

  def get_analytics_end_date(access_token, property) do
    Plausible.Google.GA4.API.get_analytics_end_date(access_token, property)
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

  def fetch_stats(site, query, pagination, search) do
    with {:ok, site} <- ensure_search_console_property(site),
         {:ok, access_token} <- maybe_refresh_token(site.google_auth),
         {:ok, gsc_filters} <-
           SearchConsole.Filters.transform(site.google_auth.property, query.filters, search),
         {:ok, stats} <-
           HTTP.list_stats(
             access_token,
             site.google_auth.property,
             Query.date_range(query),
             pagination,
             gsc_filters
           ) do
      stats
      |> Map.get("rows", [])
      |> Enum.map(&search_console_row/1)
      |> then(&{:ok, &1})
    else
      :google_property_not_configured -> {:error, :google_property_not_configured}
      :unsupported_filters -> {:error, :unsupported_filters}
      {:error, error} -> {:error, error}
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
    thirty_seconds_ago = DateTime.shift(DateTime.utc_now(), second: 30)
    NaiveDateTime.before?(expires_at, thirty_seconds_ago)
  end

  defp ensure_search_console_property(site) do
    site = Plausible.Repo.preload(site, :google_auth)

    if site.google_auth && site.google_auth.property do
      {:ok, site}
    else
      :google_property_not_configured
    end
  end

  defp search_console_row(row) do
    %{
      # We always request just one dimension at a time (`query`)
      name: row["keys"] |> List.first(),
      visitors: row["clicks"],
      impressions: row["impressions"],
      ctr: rounded_ctr(row["ctr"]),
      position: rounded_position(row["position"])
    }
  end

  defp rounded_ctr(ctr) do
    {:ok, decimal} = Decimal.cast(ctr)

    decimal
    |> Decimal.mult(100)
    |> Decimal.round(1)
    |> Decimal.to_float()
  end

  defp rounded_position(position) do
    {:ok, decimal} = Decimal.cast(position)

    decimal
    |> Decimal.round(1)
    |> Decimal.to_float()
  end

  defp client_id() do
    Keyword.fetch!(Application.get_env(:plausible, :google), :client_id)
  end

  defp redirect_uri() do
    PlausibleWeb.Endpoint.url() <> "/auth/google/callback"
  end
end
