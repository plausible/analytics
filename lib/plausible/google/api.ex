defmodule Plausible.Google.API do
  @moduledoc """
  API to Google services.
  """

  use Timex

  alias Plausible.Google.HTTP

  require Logger

  @search_console_scope URI.encode_www_form(
                          "email https://www.googleapis.com/auth/webmasters.readonly"
                        )
  @import_scope URI.encode_www_form("email https://www.googleapis.com/auth/analytics.readonly")

  @verified_permission_levels ["siteOwner", "siteFullUser", "siteRestrictedUser"]

  def search_console_authorize_url(site_id, redirect_to) do
    "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@search_console_scope}&state=" <>
      Jason.encode!([site_id, redirect_to])
  end

  def import_authorize_url(site_id, redirect_to, opts \\ []) do
    legacy = Keyword.get(opts, :legacy, true)

    "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@import_scope}&state=" <>
      Jason.encode!([site_id, redirect_to, legacy])
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
         {:ok, stats} <-
           HTTP.list_stats(
             access_token,
             site.google_auth.property,
             date_range,
             limit,
             filters["page"]
           ) do
      stats
      |> Map.get("rows", [])
      |> Enum.filter(fn row -> row["clicks"] > 0 end)
      |> Enum.map(fn row -> %{name: row["keys"], visitors: round(row["clicks"])} end)
      |> then(&{:ok, &1})
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

  defp client_id() do
    Keyword.fetch!(Application.get_env(:plausible, :google), :client_id)
  end

  defp redirect_uri() do
    PlausibleWeb.Endpoint.url() <> "/auth/google/callback"
  end
end
