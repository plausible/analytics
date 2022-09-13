defmodule Plausible.Google.Api do
  alias Plausible.Google.{ReportRequest, HTTP}
  use Timex
  require Logger

  @type google_analytics_view() :: {view_name :: String.t(), view_id :: String.t()}

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
    end
  end

  def fetch_stats(site, %{filters: %{} = filters, date_range: date_range}, limit) do
    with site <- Plausible.Repo.preload(site, :google_auth),
         {:ok, %{access_token: access_token, property: property}} <-
           refresh_if_needed(site.google_auth),
         {:ok, stats} <-
           HTTP.list_stats(access_token, property, date_range, limit, filters["page"]) do
      stats
      |> Map.get("rows", [])
      |> Enum.filter(fn row -> row["clicks"] > 0 end)
      |> Enum.map(fn row -> %{name: row["keys"], visitors: round(row["clicks"])} end)
      |> then(&{:ok, &1})
    end
  end

  @spec list_views(access_token :: String.t()) ::
          {:ok, %{(hostname :: String.t()) => [google_analytics_view()]}} | {:error, term()}
  @doc """
  Lists Google Analytics views grouped by hostname.
  """
  def list_views(access_token) do
    case HTTP.list_views_for_user(access_token) do
      {:ok, %{"items" => views}} ->
        views = Enum.group_by(views, &view_hostname/1, &view_names/1)
        {:ok, views}

      error ->
        error
    end
  end

  defp view_hostname(view) do
    case view do
      %{"websiteUrl" => url} when is_binary(url) -> url |> URI.parse() |> Map.get(:host)
      _any -> "Others"
    end
  end

  defp view_names(%{"name" => name, "id" => id}) do
    {"#{id} - #{name}", id}
  end

  @spec get_view(access_token :: String.t(), lookup_id :: String.t()) ::
          {:ok, google_analytics_view()} | {:ok, nil} | {:error, term()}
  @doc """
  Returns a single Google Analytics view if the user has access to it.
  """
  def get_view(access_token, lookup_id) do
    case list_views(access_token) do
      {:ok, views} ->
        view =
          views
          |> Map.values()
          |> List.flatten()
          |> Enum.find(fn {_name, id} -> id == lookup_id end)

        {:ok, view}

      {:error, cause} ->
        {:error, cause}
    end
  end

  @per_page 10_000
  @doc """
  API reference:
  https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet#ReportRequest

  Dimensions reference: https://ga-dev-tools.web.app/dimensions-metrics-explorer
  """
  def import_analytics(site, date_range, view_id, access_token) do
    {:ok, buffer} = Plausible.Google.Buffer.start_link()

    ReportRequest.full_report()
    |> Enum.each(fn %ReportRequest{} = report_request ->
      report_request = %ReportRequest{
        report_request
        | date_range: date_range,
          view_id: view_id,
          access_token: access_token,
          page_token: nil,
          page_size: @per_page
      }

      fetch_and_persist(site, report_request, buffer: buffer)
    end)

    Plausible.Google.Buffer.flush(buffer)
    Plausible.Google.Buffer.stop(buffer)

    :ok
  end

  @max_attempts 5
  def fetch_and_persist(site, %ReportRequest{} = report_request, opts \\ []) do
    buffer_pid = Keyword.get(opts, :buffer)
    attempt = Keyword.get(opts, :attempt, 1)
    sleep_time = Keyword.get(opts, :sleep_time, 1000)
    http_client = Keyword.get(opts, :http_client, Finch)

    case HTTP.get_report(http_client, report_request) do
      {:ok, {rows, next_page_token}} ->
        records = Plausible.Imported.from_google_analytics(rows, site.id, report_request.dataset)
        :ok = Plausible.Google.Buffer.insert_many(buffer_pid, report_request.dataset, records)

        if next_page_token do
          fetch_and_persist(
            site,
            %ReportRequest{report_request | page_token: next_page_token},
            opts
          )
        else
          :ok
        end

      error ->
        context_key = "request:#{attempt}"
        Sentry.Context.set_extra_context(%{context_key => error})

        if attempt >= @max_attempts do
          raise "Google API request failed too many times"
        else
          Process.sleep(sleep_time)
          fetch_and_persist(site, report_request, Keyword.merge(opts, attempt: attempt + 1))
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
