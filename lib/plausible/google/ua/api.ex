defmodule Plausible.Google.UA.API do
  @moduledoc """
  API for Universal Analytics
  """

  alias Plausible.Google
  alias Plausible.Google.UA

  @type google_analytics_view() :: {view_name :: String.t(), view_id :: String.t()}

  @type import_auth :: {
          access_token :: String.t(),
          refresh_token :: String.t(),
          expires_at :: String.t()
        }

  @per_page 7_500
  @backoff_factor :timer.seconds(10)
  @max_attempts 5

  @spec list_views(access_token :: String.t()) ::
          {:ok, %{(hostname :: String.t()) => [google_analytics_view()]}} | {:error, term()}
  @doc """
  Lists Google Analytics views grouped by hostname.
  """
  def list_views(access_token) do
    case UA.HTTP.list_views_for_user(access_token) do
      {:ok, %{"items" => views}} ->
        views =
          views
          |> Enum.group_by(&view_hostname/1, &view_names/1)
          |> Enum.sort_by(fn {key, _} -> key end)

        {:ok, views}

      error ->
        error
    end
  end

  @spec get_view(access_token :: String.t(), lookup_id :: String.t()) ::
          {:ok, google_analytics_view()} | {:ok, nil} | {:error, term()}
  @doc """
  Returns a single Google Analytics view if the user has access to it.
  """
  def get_view(access_token, lookup_id) do
    with {:ok, views} <- list_views(access_token) do
      views =
        views
        |> Enum.map(&elem(&1, 1))
        |> List.flatten()

      case Enum.find(views, fn {_name, id} -> id == lookup_id end) do
        {view_name, view_id} ->
          {:ok, %{id: view_id, name: "#{view_name}"}}

        nil ->
          {:error, :not_found}
      end
    end
  end

  def get_analytics_start_date(access_token, view_id) do
    UA.HTTP.get_analytics_start_date(access_token, view_id)
  end

  def get_analytics_end_date(access_token, view_id) do
    UA.HTTP.get_analytics_end_date(access_token, view_id)
  end

  @spec import_analytics(Date.Range.t(), String.t(), import_auth(), (String.t(), [map()] -> :ok)) ::
          :ok | {:error, term()}
  @doc """
  Imports stats from a Google Analytics UA view to a Plausible site.

  This function fetches Google Analytics reports in batches of #{@per_page} per
  request. The batches are then passed to persist callback.

  Requests to Google Analytics can fail, and are retried at most
  #{@max_attempts} times with an exponential backoff. Returns `:ok` when
  importing has finished or `{:error, term()}` when a request to GA failed too
  many times.

  Useful links:

  - [Feature documentation](https://plausible.io/docs/google-analytics-import)
  - [GA API reference](https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet#ReportRequest)
  - [GA Dimensions reference](https://ga-dev-tools.web.app/dimensions-metrics-explorer)

  """
  def import_analytics(date_range, view_id, auth, persist_fn) do
    with {:ok, access_token} <- Google.API.maybe_refresh_token(auth) do
      do_import_analytics(date_range, view_id, access_token, persist_fn)
    end
  end

  defp do_import_analytics(date_range, view_id, access_token, persist_fn) do
    Enum.reduce_while(UA.ReportRequest.full_report(), :ok, fn report_request, :ok ->
      report_request = %UA.ReportRequest{
        report_request
        | date_range: date_range,
          view_id: view_id,
          access_token: access_token,
          page_token: nil,
          page_size: @per_page
      }

      case fetch_and_persist(report_request, persist_fn: persist_fn) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @spec fetch_and_persist(UA.ReportRequest.t(), Keyword.t()) ::
          :ok | {:error, term()}
  def fetch_and_persist(%UA.ReportRequest{} = report_request, opts \\ []) do
    persist_fn = Keyword.fetch!(opts, :persist_fn)
    attempt = Keyword.get(opts, :attempt, 1)
    sleep_time = Keyword.get(opts, :sleep_time, @backoff_factor)

    case UA.HTTP.get_report(report_request) do
      {:ok, {rows, next_page_token}} ->
        :ok = persist_fn.(report_request.dataset, rows)

        if next_page_token do
          fetch_and_persist(
            %UA.ReportRequest{report_request | page_token: next_page_token},
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
          fetch_and_persist(report_request, Keyword.merge(opts, attempt: attempt + 1))
        end
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
end
