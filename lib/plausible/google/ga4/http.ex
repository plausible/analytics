defmodule Plausible.Google.GA4.HTTP do
  @moduledoc """
  HTTP client implementation for Google Analytics 4 API.
  """

  require Logger
  alias Plausible.HTTPClient

  @spec get_report(Plausible.Google.GA4.ReportRequest.t()) ::
          {:ok, {[map()], non_neg_integer()}} | {:error, any()}
  def get_report(%Plausible.Google.GA4.ReportRequest{} = report_request) do
    params = %{
      requests: [
        %{
          property: report_request.property,
          dateRanges: [
            %{
              startDate: report_request.date_range.first,
              endDate: report_request.date_range.last
            }
          ],
          dimensions: Enum.map(report_request.dimensions, &%{name: &1}),
          metrics: Enum.map(report_request.metrics, &build_metric/1),
          orderBys: [
            %{
              dimension: %{
                dimensionName: "date",
                orderType: "ALPHANUMERIC"
              },
              desc: true
            }
          ],
          limit: report_request.limit,
          offset: report_request.offset
        }
      ]
    }

    url =
      "#{reporting_api_url()}/v1beta/#{report_request.property}:batchRunReports"

    response =
      HTTPClient.impl().post(
        url,
        [{"Authorization", "Bearer #{report_request.access_token}"}],
        params,
        receive_timeout: 60_000
      )

    with {:ok, %{body: body}} <- response,
         # File.write!("fixture/ga4_report_#{report_request.dataset}.json", Jason.encode!(body)),
         {:ok, report} <- parse_report_from_response(body),
         row_count <- Map.get(report, "rowCount"),
         {:ok, report} <- convert_to_maps(report) do
      {:ok, {report, row_count}}
    else
      {:error, %{reason: %{status: status, body: body}}} ->
        Sentry.Context.set_extra_context(%{ga_response: %{body: body, status: status}})
        {:error, :request_failed}

      {:error, _reason} ->
        {:error, :request_failed}
    end
  end

  defp build_metric(expression) do
    case String.split(expression, " = ") do
      [name, expression] ->
        %{
          name: name,
          expression: expression
        }

      [name] ->
        %{name: name}
    end
  end

  defp parse_report_from_response(%{"reports" => [report | _]}) do
    {:ok, report}
  end

  defp parse_report_from_response(body) do
    Sentry.Context.set_extra_context(%{google_analytics4_response: body})

    Logger.error(
      "Google Analytics 4: Failed to find report in response. Reason: #{inspect(body)}"
    )

    {:error, {:invalid_response, body}}
  end

  defp convert_to_maps(%{
         "rows" => rows,
         "dimensionHeaders" => dimension_headers,
         "metricHeaders" => metric_headers
       })
       when is_list(rows) do
    dimension_headers = Enum.map(dimension_headers, & &1["name"])
    metric_headers = Enum.map(metric_headers, & &1["name"])

    report =
      Enum.map(rows, fn %{"dimensionValues" => dimensions, "metricValues" => metrics} ->
        dimension_values = Enum.map(dimensions, & &1["value"])
        metric_values = Enum.map(metrics, & &1["value"])
        metrics = Enum.zip(metric_headers, metric_values)
        dimensions = Enum.zip(dimension_headers, dimension_values)
        %{metrics: Map.new(metrics), dimensions: Map.new(dimensions)}
      end)

    {:ok, report}
  end

  defp convert_to_maps(response) do
    Logger.error(
      "Google Analytics 4: Failed to read report in response. Reason: #{inspect(response)}"
    )

    Sentry.Context.set_extra_context(%{google_analytics4_response: response})
    {:error, {:invalid_response, response}}
  end

  def list_accounts_for_user(access_token) do
    url = "#{admin_api_url()}/v1beta/accountSummaries"

    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().get(url, headers) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        {:ok, body}

      {:error, %HTTPClient.Non200Error{} = error} when error.reason.status in [401, 403] ->
        {:error, :authentication_failed}

      {:error, %HTTPClient.Non200Error{} = error} ->
        Sentry.capture_message("Error listing Google accounts for user", extra: %{error: error})
        {:error, :unknown}
    end
  end

  @earliest_valid_date "2015-08-14"
  def get_analytics_start_date(property, access_token) do
    params = %{
      requests: [
        %{
          property: "#{property}",
          dateRanges: [
            %{startDate: @earliest_valid_date, endDate: Date.to_iso8601(Timex.today())}
          ],
          dimensions: [%{name: "date"}],
          metrics: [%{name: "screenPageViews"}],
          orderBys: [
            %{dimension: %{dimensionName: "date", orderType: "ALPHANUMERIC"}, desc: false}
          ],
          limit: 1
        }
      ]
    }

    url = "#{reporting_api_url()}/v1beta/#{property}:batchRunReports"
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.post(url, headers, params) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        report = List.first(body["reports"])

        date =
          case report["rows"] do
            [%{"dimensionValues" => [%{"value" => date_str}]}] ->
              Timex.parse!(date_str, "%Y%m%d", :strftime) |> NaiveDateTime.to_date()

            _ ->
              nil
          end

        {:ok, date}

      {:error, %{reason: %Finch.Response{body: body}}} ->
        Sentry.capture_message("Error fetching GA4 start date", extra: %{body: inspect(body)})
        {:error, body}

      {:error, %{reason: reason} = e} ->
        Sentry.capture_message("Error fetching GA4 start date", extra: %{error: inspect(e)})
        {:error, reason}
    end
  end

  defp reporting_api_url, do: "https://analyticsdata.googleapis.com"
  defp admin_api_url, do: "https://analyticsadmin.googleapis.com"
end
