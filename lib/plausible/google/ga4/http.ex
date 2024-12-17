defmodule Plausible.Google.GA4.HTTP do
  @moduledoc """
  HTTP client implementation for Google Analytics 4 API.
  """

  use Plausible

  alias Plausible.HTTPClient

  require Logger

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
          dimensionFilter: report_request.dimension_filter,
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
        receive_timeout: 80_000
      )

    with {:ok, %{body: body}} <- response,
         {:ok, report} <- parse_report_from_response(body),
         row_count <- Map.get(report, "rowCount", 0),
         {:ok, report} <- convert_to_maps(report) do
      {:ok, {report, row_count}}
    else
      {:error, %{reason: %{status: 429, body: body}} = error} ->
        log_ce_error("retrieving report for #{report_request.dataset}", error)

        Logger.debug(
          "[#{inspect(__MODULE__)}:#{report_request.property}] Request failed for #{report_request.dataset} due to exceeding rate limit."
        )

        Sentry.Context.set_extra_context(%{ga_response: %{body: body, status: 429}})

        {:error,
         {:rate_limit_exceeded, dataset: report_request.dataset, offset: report_request.offset}}

      {:error, %{reason: %{status: status, body: body}} = error} when status >= 500 ->
        log_ce_error("retrieving report for #{report_request.dataset}", error)

        Logger.warning(
          "[#{inspect(__MODULE__)}:#{report_request.property}] Request failed for #{report_request.dataset} with code #{status}: #{inspect(body)}"
        )

        Sentry.Context.set_extra_context(%{ga_response: %{body: body, status: status}})

        {:error, {:server_failed, dataset: report_request.dataset, offset: report_request.offset}}

      {:error, %{reason: %{status: status, body: body}} = error} ->
        log_ce_error("retrieving report for #{report_request.dataset}", error)

        Logger.warning(
          "[#{inspect(__MODULE__)}:#{report_request.property}] Request failed for #{report_request.dataset} with code #{status}: #{inspect(body)}"
        )

        Sentry.Context.set_extra_context(%{ga_response: %{body: body, status: status}})

        {:error, :request_failed}

      {:error, reason} ->
        log_ce_error("retrieving report for #{report_request.dataset}", reason)

        Logger.warning(
          "[#{inspect(__MODULE__)}:#{report_request.property}] Request failed for #{report_request.dataset}: #{inspect(reason)}"
        )

        Sentry.Context.set_extra_context(%{ga_response: %{body: reason, status: 0}})

        {:error, {:socket_failed, dataset: report_request.dataset, offset: report_request.offset}}
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

  defp convert_to_maps(%{"dimensionHeaders" => _, "metricHeaders" => _}) do
    {:ok, []}
  end

  defp convert_to_maps(response) do
    Logger.error(
      "Google Analytics 4: Failed to read report in response. Reason: #{inspect(response)}"
    )

    Sentry.Context.set_extra_context(%{google_analytics4_response: response})
    {:error, {:invalid_response, response}}
  end

  def list_accounts_for_user(access_token) do
    url = "#{admin_api_url()}/v1beta/accountSummaries?pageSize=200"

    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().get(url, headers) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        {:ok, body}

      {:error, %HTTPClient.Non200Error{reason: %{status: 429}} = error} ->
        log_ce_error("listing accounts for user", error)
        {:error, :rate_limit_exceeded}

      {:error, %HTTPClient.Non200Error{} = error} when error.reason.status in [401, 403] ->
        log_ce_error("listing accounts for user", error)
        {:error, authentication_failed(error)}

      {:error, %{reason: :timeout} = error} ->
        log_ce_error("listing accounts for user", error)
        {:error, :timeout}

      {:error, error} ->
        log_ce_error("listing accounts for user", error)
        Sentry.capture_message("Error listing GA4 accounts for user", extra: %{error: error})
        {:error, :unknown}
    end
  end

  def get_property(access_token, property) do
    url = "#{admin_api_url()}/v1beta/#{property}"

    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().get(url, headers) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        {:ok, body}

      {:error, %HTTPClient.Non200Error{reason: %{status: 429}} = error} ->
        log_ce_error("retrieving property #{property}", error)
        {:error, :rate_limit_exceeded}

      {:error, %HTTPClient.Non200Error{} = error} when error.reason.status in [401, 403] ->
        log_ce_error("retrieving property #{property}", error)
        {:error, authentication_failed(error)}

      {:error, %HTTPClient.Non200Error{} = error} when error.reason.status in [404] ->
        log_ce_error("retrieving property #{property}", error)
        {:error, :not_found}

      {:error, %{reason: :timeout} = error} ->
        log_ce_error("retrieving property #{property}", error)
        {:error, :timeout}

      {:error, error} ->
        log_ce_error("retrieving property #{property}", error)

        Sentry.capture_message("Error retrieving GA4 property #{property}",
          extra: %{error: error}
        )

        {:error, :unknown}
    end
  end

  @earliest_valid_date "2015-08-14"

  def get_analytics_start_date(access_token, property) do
    get_analytics_boundary_date(access_token, property, :start)
  end

  def get_analytics_end_date(access_token, property) do
    get_analytics_boundary_date(access_token, property, :end)
  end

  defp get_analytics_boundary_date(access_token, property, edge) do
    descending? = edge == :end

    params = %{
      requests: [
        %{
          property: "#{property}",
          dateRanges: [
            %{startDate: @earliest_valid_date, endDate: Date.to_iso8601(Date.utc_today())}
          ],
          dimensions: [%{name: "date"}],
          metrics: [%{name: "screenPageViews"}],
          orderBys: [
            %{dimension: %{dimensionName: "date", orderType: "ALPHANUMERIC"}, desc: descending?}
          ],
          limit: 1
        }
      ]
    }

    url = "#{reporting_api_url()}/v1beta/#{property}:batchRunReports"
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().post(url, headers, params) do
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

      {:error, %HTTPClient.Non200Error{reason: %{status: 429}} = error} ->
        log_ce_error("retrieving #{edge} date", error)
        {:error, :rate_limit_exceeded}

      {:error, %HTTPClient.Non200Error{} = error} when error.reason.status in [401, 403] ->
        log_ce_error("retrieving #{edge} date", error)
        {:error, authentication_failed(error)}

      {:error, %{reason: :timeout} = error} ->
        log_ce_error("retrieving #{edge} date", error)
        {:error, :timeout}

      {:error, error} ->
        log_ce_error("retrieving #{edge} date", error)

        Sentry.capture_message("Error retrieving GA4 #{edge} date",
          extra: %{error: error}
        )

        {:error, :unknown}
    end
  end

  defp reporting_api_url, do: "https://analyticsdata.googleapis.com"
  defp admin_api_url, do: "https://analyticsadmin.googleapis.com"

  @spec authentication_failed(HTTPClient.Non200Error.t()) ::
          {:authentication_failed, String.t() | nil}
  defp authentication_failed(error) do
    message =
      case error.reason.body do
        %{"error" => %{"message" => message}} when is_binary(message) -> message
        _ -> nil
      end

    {:authentication_failed, message}
  end

  @spec log_ce_error(String.t(), any) :: :ok
  defp log_ce_error(action, error)

  on_ce do
    defp log_ce_error(action, error) do
      Logger.error("Google Analytics 4: Failed when #{action}. Reason: #{inspect(error)}")
    end
  end

  on_ee do
    defp log_ce_error(_action, _error), do: :ok
  end
end
