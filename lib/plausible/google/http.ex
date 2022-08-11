defmodule Plausible.Google.HTTP do
  @spec get_report(module(), Plausible.Google.ReportRequest.t()) ::
          {:ok, {[map()], String.t() | nil}} | {:error, any()}
  def get_report(http_client, %Plausible.Google.ReportRequest{} = report_request) do
    params =
      Jason.encode!(%{
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
      })

    response =
      :post
      |> Finch.build(
        "https://analyticsreporting.googleapis.com/v4/reports:batchGet",
        [{"Authorization", "Bearer #{report_request.access_token}"}],
        params
      )
      |> http_client.request(Plausible.Finch)

    with {:ok, %{status: 200, body: body}} <- response,
         {:ok, %{"reports" => [report | _]}} <- Jason.decode(body),
         token <- Map.get(report, "nextPageToken"),
         report <- convert_to_maps(report) do
      {:ok, {report, token}}
    end
  end

  defp convert_to_maps(%{
         "data" => %{"rows" => rows},
         "columnHeader" => %{
           "dimensions" => dimension_headers,
           "metricHeader" => %{"metricHeaderEntries" => metric_headers}
         }
       }) do
    metric_headers = Enum.map(metric_headers, & &1["name"])

    Enum.map(rows, fn %{"dimensions" => dimensions, "metrics" => [%{"values" => metrics}]} ->
      metrics = Enum.zip(metric_headers, metrics)
      dimensions = Enum.zip(dimension_headers, dimensions)
      %{metrics: Map.new(metrics), dimensions: Map.new(dimensions)}
    end)
  end

  def list_sites(access_token) do
    "https://www.googleapis.com/webmasters/v3/sites"
    |> HTTPoison.get!("Content-Type": "application/json", Authorization: "Bearer #{access_token}")
    |> Map.get(:body)
    |> Jason.decode!()
    |> then(&{:ok, &1})
  end

  def fetch_access_token(code) do
    "https://www.googleapis.com/oauth2/v4/token"
    |> HTTPoison.post!(
      "client_id=#{client_id()}&client_secret=#{client_secret()}&code=#{code}&grant_type=authorization_code&redirect_uri=#{redirect_uri()}",
      "Content-Type": "application/x-www-form-urlencoded"
    )
    |> Map.get(:body)
    |> Jason.decode!()
  end

  def list_views_for_user(access_token) do
    "https://www.googleapis.com/analytics/v3/management/accounts/~all/webproperties/~all/profiles"
    |> HTTPoison.get!(Authorization: "Bearer #{access_token}")
    |> case do
      %{body: body, status_code: 200} ->
        {:ok, Jason.decode!(body)}

      %{body: body} ->
        Sentry.capture_message("Error fetching Google view ID", extra: Jason.decode!(body))
        {:error, body}
    end
  end

  def list_stats(access_token, property, date_range, limit, page \\ nil) do
    property = URI.encode_www_form(property)

    filter_groups =
      if page do
        url = property_base_url(property)
        [%{filters: [%{dimension: "page", expression: "https://#{url}#{page}"}]}]
      else
        %{}
      end

    params =
      Jason.encode!(%{
        startDate: Date.to_iso8601(date_range.first),
        endDate: Date.to_iso8601(date_range.last),
        dimensions: ["query"],
        rowLimit: limit,
        dimensionFilterGroups: filter_groups
      })

    :post
    |> Finch.build(
      "https://www.googleapis.com/webmasters/v3/sites/#{property}/searchAnalytics/query",
      [{"Authorization", "Bearer #{access_token}"}],
      params
    )
    |> Finch.request(Plausible.Finch)
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: 401, body: body}} ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(body))
        {:error, :invalid_credentials}

      {:ok, %{status: 403, body: body}} ->
        body = Jason.decode!(body)
        Sentry.capture_message("Error fetching Google queries", extra: body)
        {:error, get_in(body, ["error", "message"])}

      {:ok, %{body: body}} ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(body))
        {:error, :unknown}
    end
  end

  defp property_base_url("sc-domain:" <> domain), do: "https://" <> domain
  defp property_base_url(url), do: url

  def refresh_auth_token(refresh_token) do
    "https://www.googleapis.com/oauth2/v4/token"
    |> HTTPoison.post!(
      "client_id=#{client_id()}&client_secret=#{client_secret()}&refresh_token=#{refresh_token}&grant_type=refresh_token&redirect_uri=#{redirect_uri()}",
      "Content-Type": "application/x-www-form-urlencoded"
    )
    |> case do
      %{body: body, status_code: 200} ->
        {:ok, Jason.decode!(body)}

      %{body: body} ->
        body
        |> Jason.decode!(body)
        |> Map.get("error")
        |> then(&{:error, &1})
    end
  end

  @earliest_valid_date "2005-01-01"
  def get_analytics_start_date(view_id, access_token) do
    params =
      Jason.encode!(%{
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
      })

    "https://analyticsreporting.googleapis.com/v4/reports:batchGet"
    |> HTTPoison.post!(
      params,
      [Authorization: "Bearer #{access_token}"],
      timeout: 15_000,
      recv_timeout: 15_000
    )
    |> case do
      %{status_code: 200, body: body} ->
        report = List.first(Jason.decode!(body)["reports"])

        date =
          case report["data"]["rows"] do
            [%{"dimensions" => [date_str]}] ->
              Timex.parse!(date_str, "%Y%m%d", :strftime) |> NaiveDateTime.to_date()

            _ ->
              nil
          end

        {:ok, date}

      %{body: body} ->
        Sentry.capture_message("Error fetching Google view ID", extra: Jason.decode!(body))
        {:error, body}
    end
  end

  defp config, do: Application.get_env(:plausible, :google)
  defp client_id, do: Keyword.fetch!(config(), :client_id)
  defp client_secret, do: Keyword.fetch!(config(), :client_secret)
  defp redirect_uri, do: PlausibleWeb.Endpoint.url() <> "/auth/google/callback"
end
