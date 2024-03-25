defmodule Plausible.Google.UA.HTTP do
  @moduledoc """
  HTTP client implementation for Universal Analytics API.
  """

  require Logger
  alias Plausible.HTTPClient

  @spec get_report(Plausible.Google.UA.ReportRequest.t()) ::
          {:ok, {[map()], String.t() | nil}} | {:error, any()}
  def get_report(%Plausible.Google.UA.ReportRequest{} = report_request) do
    params = %{
      reportRequests: [
        %{
          viewId: report_request.view_id,
          dateRanges: [
            %{
              startDate: report_request.date_range.first,
              endDate: report_request.date_range.last
            }
          ],
          dimensions: Enum.map(report_request.dimensions, &%{name: &1, histogramBuckets: []}),
          metrics: Enum.map(report_request.metrics, &%{expression: &1}),
          hideTotals: true,
          hideValueRanges: true,
          orderBys: [%{fieldName: "ga:date", sortOrder: "DESCENDING"}],
          pageSize: report_request.page_size,
          pageToken: report_request.page_token
        }
      ]
    }

    response =
      HTTPClient.impl().post(
        "#{reporting_api_url()}/v4/reports:batchGet",
        [{"Authorization", "Bearer #{report_request.access_token}"}],
        params,
        receive_timeout: 60_000
      )

    with {:ok, %{body: body}} <- response,
         {:ok, report} <- parse_report_from_response(body),
         token <- Map.get(report, "nextPageToken"),
         {:ok, report} <- convert_to_maps(report) do
      {:ok, {report, token}}
    else
      {:error, %{reason: %{status: status, body: body}}} ->
        Sentry.Context.set_extra_context(%{ga_response: %{body: body, status: status}})
        {:error, :request_failed}

      {:error, _reason} ->
        {:error, :request_failed}
    end
  end

  defp parse_report_from_response(%{"reports" => [report | _]}) do
    {:ok, report}
  end

  defp parse_report_from_response(body) do
    Sentry.Context.set_extra_context(%{universal_analytics_response: body})

    Logger.error(
      "Universal Analytics: Failed to find report in response. Reason: #{inspect(body)}"
    )

    {:error, {:invalid_response, body}}
  end

  defp convert_to_maps(%{
         "data" => %{} = data,
         "columnHeader" => %{
           "dimensions" => dimension_headers,
           "metricHeader" => %{"metricHeaderEntries" => metric_headers}
         }
       }) do
    metric_headers = Enum.map(metric_headers, & &1["name"])
    rows = Map.get(data, "rows", [])

    report =
      Enum.map(rows, fn %{"dimensions" => dimensions, "metrics" => [%{"values" => metrics}]} ->
        metrics = Enum.zip(metric_headers, metrics)
        dimensions = Enum.zip(dimension_headers, dimensions)
        %{metrics: Map.new(metrics), dimensions: Map.new(dimensions)}
      end)

    {:ok, report}
  end

  defp convert_to_maps(response) do
    Logger.error(
      "Universal Analytics: Failed to read report in response. Reason: #{inspect(response)}"
    )

    Sentry.Context.set_extra_context(%{universal_analytics_response: response})
    {:error, {:invalid_response, response}}
  end

  def list_views_for_user(access_token) do
    url = "#{api_url()}/analytics/v3/management/accounts/~all/webproperties/~all/profiles"

    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().get(url, headers) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        {:ok, body}

      {:error, %HTTPClient.Non200Error{} = error} when error.reason.status in [401, 403] ->
        {:error, :authentication_failed}

      {:error, %HTTPClient.Non200Error{} = error} ->
        Sentry.capture_message("Error listing GA views for user", extra: %{error: error})
        {:error, :unknown}
    end
  end

  @earliest_valid_date "2005-01-01"
  def get_analytics_start_date(access_token, view_id) do
    params = %{
      reportRequests: [
        %{
          viewId: view_id,
          dateRanges: [
            %{startDate: @earliest_valid_date, endDate: Date.to_iso8601(Timex.today())}
          ],
          dimensions: [%{name: "ga:date", histogramBuckets: []}],
          metrics: [%{expression: "ga:pageviews"}],
          hideTotals: true,
          hideValueRanges: true,
          orderBys: [%{fieldName: "ga:date", sortOrder: "ASCENDING"}],
          pageSize: 1
        }
      ]
    }

    url = "#{reporting_api_url()}/v4/reports:batchGet"
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().post(url, headers, params) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        report = List.first(body["reports"])

        date =
          case report["data"]["rows"] do
            [%{"dimensions" => [date_str]}] ->
              Timex.parse!(date_str, "%Y%m%d", :strftime) |> NaiveDateTime.to_date()

            _ ->
              nil
          end

        {:ok, date}

      {:error, %{reason: %Finch.Response{body: body}}} ->
        Sentry.capture_message("Error fetching UA start date", extra: %{body: inspect(body)})
        {:error, body}

      {:error, %{reason: reason} = e} ->
        Sentry.capture_message("Error fetching UA start date", extra: %{error: inspect(e)})
        {:error, reason}
    end
  end

  def get_analytics_end_date(access_token, view_id) do
    params = %{
      reportRequests: [
        %{
          viewId: view_id,
          dateRanges: [
            %{startDate: @earliest_valid_date, endDate: Date.to_iso8601(Timex.today())}
          ],
          dimensions: [%{name: "ga:date", histogramBuckets: []}],
          metrics: [%{expression: "ga:pageviews"}],
          hideTotals: true,
          hideValueRanges: true,
          orderBys: [%{fieldName: "ga:date", sortOrder: "DESCENDING"}],
          pageSize: 1
        }
      ]
    }

    url = "#{reporting_api_url()}/v4/reports:batchGet"
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().post(url, headers, params) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        report = List.first(body["reports"])

        date =
          case report["data"]["rows"] do
            [%{"dimensions" => [date_str]}] ->
              Timex.parse!(date_str, "%Y%m%d", :strftime) |> NaiveDateTime.to_date()

            _ ->
              nil
          end

        {:ok, date}

      {:error, %{reason: %Finch.Response{body: body}}} ->
        Sentry.capture_message("Error fetching UA start date", extra: %{body: inspect(body)})
        {:error, body}

      {:error, %{reason: reason} = e} ->
        Sentry.capture_message("Error fetching UA start date", extra: %{error: inspect(e)})
        {:error, reason}
    end
  end

  defp config, do: Application.get_env(:plausible, :google)
  defp reporting_api_url, do: Keyword.fetch!(config(), :reporting_api_url)
  defp api_url, do: Keyword.fetch!(config(), :api_url)
end
