defmodule Plausible.Google.Api do
  alias Plausible.Imported

  @scope URI.encode_www_form(
           "https://www.googleapis.com/auth/webmasters.readonly email https://www.googleapis.com/auth/analytics.readonly"
         )
  @verified_permission_levels ["siteOwner", "siteFullUser", "siteRestrictedUser"]

  def authorize_url(site_id, redirect_to) do
    if Application.get_env(:plausible, :environment) == "test" do
      ""
    else
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{redirect_uri()}&prompt=consent&response_type=code&access_type=offline&scope=#{@scope}&state=" <>
        Jason.encode!([site_id, redirect_to])
    end
  end

  def fetch_access_token(code) do
    res =
      HTTPoison.post!(
        "https://www.googleapis.com/oauth2/v4/token",
        "client_id=#{client_id()}&client_secret=#{client_secret()}&code=#{code}&grant_type=authorization_code&redirect_uri=#{redirect_uri()}",
        "Content-Type": "application/x-www-form-urlencoded"
      )

    Jason.decode!(res.body)
  end

  def fetch_verified_properties(auth) do
    with {:ok, auth} <- refresh_if_needed(auth) do
      res =
        HTTPoison.get!("https://www.googleapis.com/webmasters/v3/sites",
          "Content-Type": "application/json",
          Authorization: "Bearer #{auth.access_token}"
        )

      domains =
        Jason.decode!(res.body)
        |> Map.get("siteEntry", [])
        |> Enum.filter(fn site -> site["permissionLevel"] in @verified_permission_levels end)
        |> Enum.map(fn site -> site["siteUrl"] end)
        |> Enum.map(fn url -> String.trim_trailing(url, "/") end)

      {:ok, domains}
    else
      err -> err
    end
  end

  defp property_base_url(property) do
    case property do
      "sc-domain:" <> domain -> "https://" <> domain
      url -> url
    end
  end

  def fetch_stats(site, query, limit) do
    with {:ok, auth} <- refresh_if_needed(site.google_auth) do
      do_fetch_stats(auth, query, limit)
    else
      err -> err
    end
  end

  defp do_fetch_stats(auth, query, limit) do
    property = URI.encode_www_form(auth.property)
    base_url = property_base_url(auth.property)

    filter_groups =
      if query.filters["page"] do
        [
          %{
            filters: [
              %{
                dimension: "page",
                expression: "https://#{base_url}#{query.filters["page"]}"
              }
            ]
          }
        ]
      end

    res =
      HTTPoison.post!(
        "https://www.googleapis.com/webmasters/v3/sites/#{property}/searchAnalytics/query",
        Jason.encode!(%{
          startDate: Date.to_iso8601(query.date_range.first),
          endDate: Date.to_iso8601(query.date_range.last),
          dimensions: ["query"],
          rowLimit: limit,
          dimensionFilterGroups: filter_groups || %{}
        }),
        "Content-Type": "application/json",
        Authorization: "Bearer #{auth.access_token}"
      )

    case res.status_code do
      200 ->
        terms =
          (Jason.decode!(res.body)["rows"] || [])
          |> Enum.filter(fn row -> row["clicks"] > 0 end)
          |> Enum.map(fn row -> %{name: row["keys"], visitors: round(row["clicks"])} end)

        {:ok, terms}

      401 ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(res.body))
        {:error, :invalid_credentials}

      403 ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(res.body))
        msg = Jason.decode!(res.body)["error"]["message"]
        {:error, msg}

      _ ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(res.body))
        {:error, :unknown}
    end
  end

  def get_analytics_view_ids(site) do
    with {:ok, auth} <- refresh_if_needed(site.google_auth) do
      do_get_analytics_view_ids(auth)
    end
  end

  def do_get_analytics_view_ids(auth) do
    res =
      HTTPoison.get!(
        "https://www.googleapis.com/analytics/v3/management/accounts/~all/webproperties/~all/profiles",
        Authorization: "Bearer #{auth.access_token}"
      )

    case res.status_code do
      200 ->
        profiles =
          Jason.decode!(res.body)
          |> Map.get("items")
          |> Enum.map(fn item ->
            uri = URI.parse(Map.get(item, "websiteUrl"))
            name = Map.get(item, "name")
            {"#{uri.host} - #{name}", Map.get(item, "id")}
          end)
          |> Map.new()

        {:ok, profiles}

      _ ->
        Sentry.capture_message("Error fetching Google view ID", extra: Jason.decode!(res.body))
        {:error, res.body}
    end
  end

  def import_analytics(site, profile) do
    with {:ok, auth} <- refresh_if_needed(site.google_auth) do
      do_import_analytics(site, auth, profile)
    end
  end

  @doc """
  API reference:
  https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet#ReportRequest

  Dimensions reference: https://ga-dev-tools.web.app/dimensions-metrics-explorer
  """
  def do_import_analytics(site, auth, profile) do
    end_date =
      Plausible.Stats.Clickhouse.pageviews_begin(site)
      |> NaiveDateTime.to_date()

    start_date = Date.add(end_date, -365)

    request = %{
      auth: auth,
      profile: profile,
      start_date: Date.to_iso8601(start_date),
      end_date: Date.to_iso8601(end_date)
    }

    request_data = [
      # Visitors
      {
        ["ga:date"],
        [
          "ga:users",
          "ga:pageviews",
          "ga:bounceRate",
          "ga:avgSessionDuration"
        ]
      },
      # Sources
      {
        ["ga:date", "ga:source"],
        ["ga:users"]
      },
      # UTM Mediums
      {
        ["ga:date", "ga:medium"],
        ["ga:users"]
      },
      # UTM Campaigns
      {
        ["ga:date", "ga:campaign"],
        ["ga:users"]
      }
    ]

    response = fetch_analytic_reports(request, request_data)

    case response do
      {:ok, data} ->
        maybe_error =
          ["visitors", "sources", "utm_mediums", "utm_campaigns"]
          |> Enum.with_index()
          |> Enum.map(fn {metric, index} ->
            Task.async(fn ->
              Enum.fetch!(data, index)
              |> Imported.from_google_analytics(site.domain, metric)
            end)
          end)
          |> Enum.map(&Task.await/1)
          |> Keyword.get(:error)

        case maybe_error do
          nil ->
            {:ok, nil}

          {:error, error} ->
            Plausible.ClickhouseRepo.clear_imported_stats_for(site.domain)

            Sentry.capture_message("Error saving Google analytics data", extra: error)
            {:error, error}
        end

      {:error, error} ->
        Sentry.capture_message("Error fetching Google analytics data", extra: error)
        {:error, error}
    end
  end

  defp fetch_analytic_reports(request, request_data) do
    reports =
      Enum.map(request_data, fn {dimensions, metrics} ->
        %{
          viewId: request.profile,
          dateRanges: [
            %{
              startDate: request.start_date,
              endDate: request.end_date
            }
          ],
          dimensions: Enum.map(dimensions, &%{name: &1, histogramBuckets: []}),
          metrics: Enum.map(metrics, &%{expression: &1}),
          hideTotals: true,
          hideValueRanges: true
        }
      end)

    res =
      HTTPoison.post!(
        "https://analyticsreporting.googleapis.com/v4/reports:batchGet",
        Jason.encode!(%{reportRequests: reports}),
        Authorization: "Bearer #{request.auth.access_token}"
      )

    if res.status_code == 200 do
      data =
        Jason.decode!(res.body)["reports"]
        |> Enum.map(& &1["data"]["rows"])

      {:ok, data}
    else
      {:error, Jason.decode!(res.body)}
    end
  end

  defp refresh_if_needed(auth) do
    if Timex.before?(auth.expires, Timex.now() |> Timex.shift(seconds: 30)) do
      refresh_token(auth)
    else
      {:ok, auth}
    end
  end

  defp refresh_token(auth) do
    res =
      HTTPoison.post!(
        "https://www.googleapis.com/oauth2/v4/token",
        "client_id=#{client_id()}&client_secret=#{client_secret()}&refresh_token=#{auth.refresh_token}&grant_type=refresh_token&redirect_uri=#{redirect_uri()}",
        "Content-Type": "application/x-www-form-urlencoded"
      )

    body = Jason.decode!(res.body)

    if res.status_code == 200 do
      Plausible.Site.GoogleAuth.changeset(auth, %{
        access_token: body["access_token"],
        expires: NaiveDateTime.utc_now() |> NaiveDateTime.add(body["expires_in"])
      })
      |> Plausible.Repo.update()
    else
      {:error, body["error"]}
    end
  end

  defp client_id() do
    Keyword.fetch!(Application.get_env(:plausible, :google), :client_id)
  end

  defp client_secret() do
    Keyword.fetch!(Application.get_env(:plausible, :google), :client_secret)
  end

  defp redirect_uri() do
    PlausibleWeb.Endpoint.url() <> "/auth/google/callback"
  end
end
