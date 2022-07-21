defmodule Plausible.Google.Api do
  alias Plausible.{Imported, Google.HTTP}
  use Timex
  require Logger

  @scope URI.encode_www_form(
           "https://www.googleapis.com/auth/webmasters.readonly email https://www.googleapis.com/auth/analytics.readonly"
         )
  @import_scope URI.encode_www_form("email https://www.googleapis.com/auth/analytics.readonly")
  @verified_permission_levels ["siteOwner", "siteFullUser", "siteRestrictedUser"]

  def authorize_url(site_id, redirect_to) do
    if Application.get_env(:plausible, :environment) == "test" do
      ""
    else
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@scope}&state=" <>
        Jason.encode!([site_id, redirect_to])
    end
  end

  def import_authorize_url(site_id, redirect_to) do
    if Application.get_env(:plausible, :environment) == "test" do
      ""
    else
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@import_scope}&state=" <>
        Jason.encode!([site_id, redirect_to])
    end
  end

  def fetch_verified_properties(auth) do
    with {:ok, auth} <- refresh_if_needed(auth),
         {:ok, sites} <- Plausible.Google.HTTP.list_sites(auth.access_token) do
      sites
      |> Map.get("siteEntry", [])
      |> Enum.filter(fn site -> site["permissionLevel"] in @verified_permission_levels end)
      |> Enum.map(fn site -> site["siteUrl"] end)
      |> Enum.map(fn url -> String.trim_trailing(url, "/") end)
      |> then(&{:ok, &1})
    else
      err -> err
    end
  end

  def fetch_stats(site, %{date_range: date_range, filters: %{"page" => page}}, limit) do
    with {:ok, %{access_token: access_token, property: property}} <-
           refresh_if_needed(site.google_auth),
         {:ok, stats} <- HTTP.list_stats(access_token, property, date_range, limit, page) do
      stats
      |> Map.get("rows", [])
      |> Enum.filter(fn row -> row["clicks"] > 0 end)
      |> Enum.map(fn row -> %{name: row["keys"], visitors: round(row["clicks"])} end)
    else
      any -> any
    end
  end

  def get_analytics_view_ids(access_token) do
    case HTTP.list_views_for_user(access_token) do
      {:ok, %{"items" => views}} ->
        view_ids = for view <- views, do: build_view_ids(view), into: %{}
        {:ok, view_ids}

      error ->
        error
    end
  end

  defp build_view_ids(view) do
    uri = URI.parse(Map.get(view, "websiteUrl", ""))

    if !uri.host do
      Sentry.capture_message("No URI for view ID", extra: view)
    end

    host = uri.host || Map.get(view, "id", "")
    name = Map.get(view, "name")
    {"#{host} - #{name}", Map.get(view, "id")}
  end

  # Each element is: {dataset, dimensions, metrics}
  @request_data [
    {
      "imported_visitors",
      ["ga:date"],
      [
        "ga:users",
        "ga:pageviews",
        "ga:bounces",
        "ga:sessions",
        "ga:sessionDuration"
      ]
    },
    {
      "imported_sources",
      ["ga:date", "ga:source", "ga:medium", "ga:campaign", "ga:adContent", "ga:keyword"],
      ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
    },
    {
      "imported_pages",
      ["ga:date", "ga:hostname", "ga:pagePath"],
      ["ga:users", "ga:pageviews", "ga:exits", "ga:timeOnPage"]
    },
    {
      "imported_entry_pages",
      ["ga:date", "ga:landingPagePath"],
      ["ga:users", "ga:entrances", "ga:sessionDuration", "ga:bounces"]
    },
    {
      "imported_exit_pages",
      ["ga:date", "ga:exitPagePath"],
      ["ga:users", "ga:exits"]
    },
    {
      "imported_locations",
      ["ga:date", "ga:countryIsoCode", "ga:regionIsoCode"],
      ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
    },
    {
      "imported_devices",
      ["ga:date", "ga:deviceCategory"],
      ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
    },
    {
      "imported_browsers",
      ["ga:date", "ga:browser"],
      ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
    },
    {
      "imported_operating_systems",
      ["ga:date", "ga:operatingSystem"],
      ["ga:users", "ga:sessions", "ga:bounces", "ga:sessionDuration"]
    }
  ]

  @one_day_in_ms 86_400_000
  @doc """
  API reference:
  https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet#ReportRequest

  Dimensions reference: https://ga-dev-tools.web.app/dimensions-metrics-explorer
  """
  def import_analytics(site, date_range, view_id, access_token) do
    @request_data
    |> Task.async_stream(
      fn {dataset, dimensions, metrics} ->
        fetch_and_persist(
          site,
          %{
            dataset: dataset,
            dimensions: dimensions,
            metrics: metrics,
            date_range: date_range,
            view_id: view_id,
            access_token: access_token,
            page_token: nil
          }
        )
      end,
      ordered: false,
      max_concurrency: 3,
      timeout: @one_day_in_ms
    )
    |> Stream.run()
  end

  @max_attempts 5
  def fetch_and_persist(site, request, opts \\ []) do
    http_client = Keyword.get(opts, :http_client, HTTPoison)
    attempt = Keyword.get(opts, :attempt, 1)
    sleep_time = Keyword.get(opts, :sleep_time, 1000)

    case HTTP.get_report(
           http_client,
           request.access_token,
           request.view_id,
           request.date_range,
           request.dimensions,
           request.metrics,
           10_000,
           request.page_token
         ) do
      {:ok, {rows, nil}} ->
        Imported.from_google_analytics(rows, site.id, request.dataset)
        :ok

      {:ok, {rows, next_page_token}} ->
        Imported.from_google_analytics(rows, site.id, request.dataset)
        fetch_and_persist(site, %{request | page_token: next_page_token})

      error ->
        context_key = "request:#{attempt}"
        Sentry.Context.set_extra_context(%{context_key => error})

        if attempt >= @max_attempts do
          raise "Google API request failed too many times"
        else
          Process.sleep(sleep_time)
          fetch_and_persist(site, request, Keyword.merge(opts, attempt: attempt + 1))
        end
    end
  end

  defp refresh_if_needed(auth) do
    if Timex.before?(auth.expires, Timex.now() |> Timex.shift(seconds: 30)) do
      do_refresh_token(auth)
    else
      {:ok, auth}
    end
  end

  defp do_refresh_token(auth) do
    case HTTP.refresh_auth_token(auth.refresh_token) do
      {:ok, %{"access_token" => access_token, "expires_in" => expires_in}} ->
        expires_in = NaiveDateTime.add(NaiveDateTime.utc_now(), expires_in)

        auth
        |> Plausible.Site.GoogleAuth.changeset(%{access_token: access_token, expires: expires_in})
        |> Plausible.Repo.update()

      error ->
        error
    end
  end

  defp client_id() do
    Keyword.fetch!(Application.get_env(:plausible, :google), :client_id)
  end

  defp redirect_uri() do
    PlausibleWeb.Endpoint.url() <> "/auth/google/callback"
  end
end
