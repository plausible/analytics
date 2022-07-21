defmodule Plausible.Google.HTTP do
  def get_report(
        http_client,
        access_token,
        view_id,
        date_range,
        dimensions,
        metrics,
        page_size,
        pagination_token
      ) do
    params =
      Jason.encode!(%{
        reportRequests: [
          %{
            viewId: view_id,
            dateRanges: [%{startDate: date_range.first, endDate: date_range.last}],
            dimensions: Enum.map(dimensions, &%{name: &1, histogramBuckets: []}),
            metrics: Enum.map(metrics, &%{expression: &1}),
            hideTotals: true,
            hideValueRanges: true,
            orderBys: [%{fieldName: "ga:date", sortOrder: "DESCENDING"}],
            pageSize: page_size,
            pageToken: pagination_token
          }
        ]
      })

    response =
      http_client.post(
        "https://analyticsreporting.googleapis.com/v4/reports:batchGet",
        params,
        [Authorization: "Bearer #{access_token}"],
        timeout: 30_000,
        recv_timeout: 30_000
      )

    with {:ok, %{status_code: 200, body: body}} <- response,
         {:ok, %{"reports" => [report | _]}} <- Jason.decode(body),
         token <- Map.get(report, "nextPageToken"),
         {:ok, data} <- get_non_empty_rows(report) do
      {:ok, {data, token}}
    else
      error -> error
    end
  end

  defp get_non_empty_rows(report) do
    case get_in(report, ["data", "rows"]) do
      [] -> {:error, :empty_response_rows}
      rows -> {:ok, rows}
    end
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

    "https://www.googleapis.com/webmasters/v3/sites/#{property}/searchAnalytics/query"
    |> HTTPoison.post!(params,
      "Content-Type": "application/json",
      Authorization: "Bearer #{access_token}"
    )
    |> case do
      %{status_code: 200, body: body} ->
        {:ok, Jason.decode!(body)}

      %{status_code: 401, body: body} ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(body))
        {:error, :invalid_credentials}

      %{status_code: 403, body: body} ->
        body = Jason.decode!(body)
        Sentry.capture_message("Error fetching Google queries", extra: body)
        {:error, get_in(body, ["error", "message"])}

      %{body: body} ->
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
