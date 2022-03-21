defmodule Plausible.Google.Api do
  alias Plausible.Imported
  use Timex
  require Logger

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

  def import_analytics(site, view_id, end_date) do
    with {:ok, auth} <- refresh_if_needed(site.google_auth) do
      do_import_analytics(site, auth, view_id, end_date)
    end
  end

  @doc """
  API reference:
  https://developers.google.com/analytics/devguides/reporting/core/v4/rest/v4/reports/batchGet#ReportRequest

  Dimensions reference: https://ga-dev-tools.web.app/dimensions-metrics-explorer
  """
  def do_import_analytics(site, auth, view_id, end_date) do
    request = %{
      auth: auth,
      profile: view_id,
      end_date: end_date
    }

    # Each element is: {dataset, dimensions, metrics}
    request_data = [
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

    responses =
      Enum.map(
        request_data,
        fn {dataset, dimensions, metrics} ->
          fetch_analytic_reports(dataset, dimensions, metrics, request)
        end
      )

    Logger.debug(responses)

    case Keyword.get(responses, :error) do
      nil ->
        results =
          responses
          |> Enum.map(fn {:ok, resp} -> resp end)
          |> Enum.concat()

        if Enum.any?(results, fn {_, val} -> val end) do
          maybe_error =
            results
            |> Enum.map(fn {dataset, data} ->
              Imported.from_google_analytics(data, site.id, dataset)
            end)
            |> Keyword.get(:error)

          case maybe_error do
            nil ->
              {:ok, nil}

            {:error, error} ->
              Plausible.ClickhouseRepo.clear_imported_stats_for(site.domain)

              Sentry.capture_message("Error saving Google analytics data", extra: error)
              {:error, error["error"]["message"]}
          end
        else
          {:error, "No Google Analytics data found."}
        end

      error ->
        Sentry.capture_message("Error fetching Google analytics data", extra: error)
        {:error, error}
    end
  end

  defp fetch_analytic_reports(dataset, dimensions, metrics, request, page_token \\ "") do
    report = %{
      viewId: request.profile,
      dateRanges: [
        %{
          # The earliest valid date
          startDate: "2005-01-01",
          endDate: request.end_date
        }
      ],
      dimensions: Enum.map(dimensions, &%{name: &1, histogramBuckets: []}),
      metrics: Enum.map(metrics, &%{expression: &1}),
      hideTotals: true,
      hideValueRanges: true,
      orderBys: [
        %{
          fieldName: "ga:date",
          sortOrder: "DESCENDING"
        }
      ],
      pageSize: 100_00,
      pageToken: page_token
    }

    res =
      HTTPoison.post!(
        "https://analyticsreporting.googleapis.com/v4/reports:batchGet",
        Jason.encode!(%{reportRequests: [report]}),
        Authorization: "Bearer #{request.auth.access_token}"
      )

    if res.status_code == 200 do
      report = List.first(Jason.decode!(res.body)["reports"])
      data = report["data"]["rows"]
      next_page_token = report["nextPageToken"]

      if next_page_token do
        # Recursively make more requests until we run out of next page tokens
        case fetch_analytic_reports(
               dataset,
               dimensions,
               metrics,
               request,
               next_page_token
             ) do
          {:ok, %{^dataset => remainder}} ->
            {:ok, %{dataset => data ++ remainder}}

          error ->
            error
        end
      else
        {:ok, %{dataset => data}}
      end
    else
      {:error, Jason.decode!(res.body)["error"]["message"]}
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
