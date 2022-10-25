defmodule Plausible.Google.Api do
  alias Plausible.Google.{ReportRequest, HTTP}
  use Timex
  require Logger

  @type google_analytics_view() :: {view_name :: String.t(), view_id :: String.t()}

  @search_console_scope URI.encode_www_form(
                          "email https://www.googleapis.com/auth/webmasters.readonly"
                        )
  @import_scope URI.encode_www_form("email https://www.googleapis.com/auth/analytics.readonly")

  @verified_permission_levels ["siteOwner", "siteFullUser", "siteRestrictedUser"]

  def search_console_authorize_url(site_id, redirect_to) do
    "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@search_console_scope}&state=" <>
      Jason.encode!([site_id, redirect_to])
  end

  def import_authorize_url(site_id, redirect_to) do
    "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@import_scope}&state=" <>
      Jason.encode!([site_id, redirect_to])
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

  @type import_auth :: {
          access_token :: String.t(),
          refresh_token :: String.t(),
          expires_at :: String.t()
        }

  @per_page 7_500
  @backoff_factor :timer.seconds(10)
  @max_attempts 5
  @spec import_analytics(Plausible.Site.t(), Date.Range.t(), String.t(), import_auth()) ::
          :ok | {:error, term()}
  @doc """
  Imports stats from a Google Analytics UA view to a Plausible site.

  This function fetches Google Analytics reports in batches of #{@per_page} per
  request. The batches are then buffered to Clickhouse by the
  `Plausible.Google.Buffer` process.

  Requests to Google Analytics can fail, and are retried at most
  #{@max_attempts} times with an exponential backoff. Returns `:ok` when
  importing has finished or `{:error, term()}` when a request to GA failed too 
  many times.

  Useful links:

  - [Feature documentation](https://plausible.io/docs/google-analytics-import)
  - [GA API reference](https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet#ReportRequest)
  - [GA Dimensions reference](https://ga-dev-tools.web.app/dimensions-metrics-explorer)

  """
  def import_analytics(site, date_range, view_id, auth) do
    with {:ok, access_token} <- maybe_refresh_token(auth),
         :ok <- do_import_analytics(site, date_range, view_id, access_token) do
      :ok
    else
      {:error, cause} ->
        Sentry.capture_message("Failed to import from Google Analytics",
          extra: %{site: site.domain, error: inspect(cause)}
        )

        {:error, cause}
    end
  end

  defp do_import_analytics(site, date_range, view_id, access_token) do
    {:ok, buffer} = Plausible.Google.Buffer.start_link()

    result =
      Enum.reduce_while(ReportRequest.full_report(), :ok, fn report_request, :ok ->
        report_request = %ReportRequest{
          report_request
          | date_range: date_range,
            view_id: view_id,
            access_token: access_token,
            page_token: nil,
            page_size: @per_page
        }

        case fetch_and_persist(site, report_request, buffer: buffer) do
          :ok -> {:cont, :ok}
          {:error, _} = error -> {:halt, error}
        end
      end)

    Plausible.Google.Buffer.flush(buffer)
    Plausible.Google.Buffer.stop(buffer)

    result
  end

  @spec fetch_and_persist(Plausible.Site.t(), ReportRequest.t(), Keyword.t()) ::
          :ok | {:error, term()}
  def fetch_and_persist(site, %ReportRequest{} = report_request, opts \\ []) do
    buffer_pid = Keyword.get(opts, :buffer)
    attempt = Keyword.get(opts, :attempt, 1)
    sleep_time = Keyword.get(opts, :sleep_time, @backoff_factor)

    case HTTP.get_report(report_request) do
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

      {:error, cause} ->
        if attempt >= @max_attempts do
          {:error, cause}
        else
          Process.sleep(attempt * sleep_time)
          fetch_and_persist(site, report_request, Keyword.merge(opts, attempt: attempt + 1))
        end
    end
  end

  defp maybe_refresh_token(%Plausible.Site.GoogleAuth{} = auth) do
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

  defp maybe_refresh_token({access_token, refresh_token, expires_at}) do
    with true <- needs_to_refresh_token?(expires_at),
         {:ok, {new_access_token, _expires_at}} <- do_refresh_token(refresh_token) do
      {:ok, new_access_token}
    else
      false -> {:ok, access_token}
      {:error, cause} -> {:error, cause}
    end
  end

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
