defmodule Plausible.Imported.UniversalAnalytics do
  @moduledoc """
  Import implementation for Universal Analytics.
  """

  use Plausible.Imported.Importer

  @missing_values ["(none)", "(not set)", "(not provided)", "(other)"]

  @impl true
  def name(), do: :universal_analytics

  @impl true
  def label(), do: "Google Analytics"

  @impl true
  def email_template(), do: :google_analytics_import

  @impl true
  def parse_args(
        %{"view_id" => view_id, "start_date" => start_date, "end_date" => end_date} = args
      ) do
    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)
    date_range = Date.range(start_date, end_date)

    auth = {
      Map.fetch!(args, "access_token"),
      Map.fetch!(args, "refresh_token"),
      Map.fetch!(args, "token_expires_at")
    }

    [
      view_id: view_id,
      date_range: date_range,
      auth: auth
    ]
  end

  @doc """
  Imports stats from a Google Analytics UA view to a Plausible site.

  This function fetches Google Analytics reports which are then passed in batches
  to Clickhouse by the `Plausible.Imported.Buffer` process.
  """
  @impl true
  def import_data(site_import, opts) do
    date_range = Keyword.fetch!(opts, :date_range)
    view_id = Keyword.fetch!(opts, :view_id)
    auth = Keyword.fetch!(opts, :auth)

    {:ok, buffer} = Plausible.Imported.Buffer.start_link()

    persist_fn = fn table, rows ->
      records = from_report(rows, site_import.site_id, site_import.id, table)
      Plausible.Imported.Buffer.insert_many(buffer, table, records)
    end

    try do
      Plausible.Google.UA.API.import_analytics(date_range, view_id, auth, persist_fn)
    after
      Plausible.Imported.Buffer.flush(buffer)
      Plausible.Imported.Buffer.stop(buffer)
    end
  end

  def from_report(nil, _site_id, _import_id, _metric), do: nil

  def from_report(data, site_id, import_id, table) do
    Enum.reduce(data, [], fn row, acc ->
      if Map.get(row.dimensions, "ga:date") in @missing_values do
        acc
      else
        [new_from_report(site_id, import_id, table, row) | acc]
      end
    end)
  end

  defp parse_number(nr) do
    {float, ""} = Float.parse(nr)
    round(float)
  end

  defp new_from_report(site_id, import_id, "imported_visitors", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("ga:pageviews") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_sources", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      source: row.dimensions |> Map.fetch!("ga:source") |> parse_referrer(),
      utm_medium: row.dimensions |> Map.fetch!("ga:medium") |> default_if_missing(),
      utm_campaign: row.dimensions |> Map.fetch!("ga:campaign") |> default_if_missing(),
      utm_content: row.dimensions |> Map.fetch!("ga:adContent") |> default_if_missing(),
      utm_term: row.dimensions |> Map.fetch!("ga:keyword") |> default_if_missing(),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_pages", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      hostname: row.dimensions |> Map.fetch!("ga:hostname") |> String.replace_prefix("www.", ""),
      page: row.dimensions |> Map.fetch!("ga:pagePath") |> URI.parse() |> Map.get(:path),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("ga:pageviews") |> parse_number(),
      exits: row.metrics |> Map.fetch!("ga:exits") |> parse_number(),
      time_on_page: row.metrics |> Map.fetch!("ga:timeOnPage") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_entry_pages", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      entry_page: row.dimensions |> Map.fetch!("ga:landingPagePath"),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      entrances: row.metrics |> Map.fetch!("ga:entrances") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_exit_pages", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      exit_page: Map.fetch!(row.dimensions, "ga:exitPagePath"),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      exits: row.metrics |> Map.fetch!("ga:exits") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_locations", row) do
    country_code = row.dimensions |> Map.fetch!("ga:countryIsoCode") |> default_if_missing("")
    city_name = row.dimensions |> Map.fetch!("ga:city") |> default_if_missing("")
    city_data = Location.get_city(city_name, country_code)

    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      country: country_code,
      region: row.dimensions |> Map.fetch!("ga:regionIsoCode") |> default_if_missing(""),
      city: city_data && city_data.id,
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_devices", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      device: row.dimensions |> Map.fetch!("ga:deviceCategory") |> String.capitalize(),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  @browser_google_to_plausible %{
    "User-Agent:Opera" => "Opera",
    "Mozilla Compatible Agent" => "Mobile App",
    "Android Webview" => "Mobile App",
    "Android Browser" => "Mobile App",
    "Safari (in-app)" => "Mobile App",
    "User-Agent: Mozilla" => "Firefox",
    "(not set)" => ""
  }

  defp new_from_report(site_id, import_id, "imported_browsers", row) do
    browser = Map.fetch!(row.dimensions, "ga:browser")

    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      browser: Map.get(@browser_google_to_plausible, browser, browser),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  @os_google_to_plausible %{
    "Macintosh" => "Mac",
    "Linux" => "GNU/Linux",
    "(not set)" => ""
  }

  defp new_from_report(site_id, import_id, "imported_operating_systems", row) do
    os = Map.fetch!(row.dimensions, "ga:operatingSystem")

    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      operating_system: Map.get(@os_google_to_plausible, os, os),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  defp get_date(%{dimensions: %{"ga:date" => date}}) do
    date
    |> Timex.parse!("%Y%m%d", :strftime)
    |> NaiveDateTime.to_date()
  end

  defp default_if_missing(value, default \\ nil)
  defp default_if_missing(value, default) when value in @missing_values, do: default
  defp default_if_missing(value, _default), do: value

  defp parse_referrer(nil), do: nil
  defp parse_referrer("(direct)"), do: nil
  defp parse_referrer("google"), do: "Google"
  defp parse_referrer("bing"), do: "Bing"
  defp parse_referrer("duckduckgo"), do: "DuckDuckGo"

  defp parse_referrer(ref) do
    RefInspector.parse("https://" <> ref)
    |> PlausibleWeb.RefInspector.parse()
  end
end
