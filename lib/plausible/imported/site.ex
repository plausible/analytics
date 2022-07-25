defmodule Plausible.Imported do
  use Plausible.ClickhouseRepo
  use Timex
  require Logger

  def forget(site) do
    Plausible.ClickhouseRepo.clear_imported_stats_for(site.id)
  end

  def from_google_analytics(nil, _site_id, _metric), do: nil

  def from_google_analytics(data, site_id, table) do
    Enum.map(data, fn row -> new_from_google_analytics(site_id, table, row) end)
  end

  defp parse_number(nr) do
    {float, ""} = Float.parse(nr)
    float
  end

  defp new_from_google_analytics(site_id, "imported_visitors", row) do
    %{
      site_id: site_id,
      date: get_date(row),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("ga:pageviews") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  defp new_from_google_analytics(site_id, "imported_sources", row) do
    %{
      site_id: site_id,
      date: get_date(row),
      source: row.dimensions |> Map.fetch!("ga:source") |> parse_referrer(),
      utm_medium: row.dimensions |> Map.fetch!("ga:medium") |> nil_if_missing(),
      utm_campaign: row.dimensions |> Map.fetch!("ga:campaign") |> nil_if_missing(),
      utm_content: row.dimensions |> Map.fetch!("ga:adContent") |> nil_if_missing(),
      utm_term: row.dimensions |> Map.fetch!("ga:keyword") |> nil_if_missing(),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  defp new_from_google_analytics(site_id, "imported_pages", row) do
    %{
      site_id: site_id,
      date: get_date(row),
      hostname: row.dimensions |> Map.fetch!("ga:hostname") |> String.replace_prefix("www.", ""),
      page: row.dimensions |> Map.fetch!("ga:pagePath") |> URI.parse() |> Map.get(:path),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("ga:pageviews") |> parse_number(),
      exits: row.metrics |> Map.fetch!("ga:exits") |> parse_number(),
      time_on_page: row.metrics |> Map.fetch!("ga:timeOnPage") |> parse_number()
    }
  end

  defp new_from_google_analytics(site_id, "imported_entry_pages", row) do
    %{
      site_id: site_id,
      date: get_date(row),
      entry_page: row.dimensions |> Map.fetch!("ga:landingPagePath"),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      entrances: row.metrics |> Map.fetch!("ga:entrances") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number()
    }
  end

  defp new_from_google_analytics(site_id, "imported_exit_pages", row) do
    %{
      site_id: site_id,
      date: get_date(row),
      exit_page: Map.fetch!(row.dimensions, "ga:exitPagePath"),
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      exits: row.metrics |> Map.fetch!("ga:exits") |> parse_number()
    }
  end

  defp new_from_google_analytics(site_id, "imported_locations", row) do
    country = Map.fetch!(row.dimensions, "ga:countryIsoCode")
    region = Map.fetch!(row.dimensions, "ga:regionIsoCode")
    country = if country == "(not set)", do: "", else: country
    region = if region == "(not set)", do: "", else: region

    %{
      site_id: site_id,
      date: get_date(row),
      country: country,
      region: region,
      city: 0,
      visitors: row.metrics |> Map.fetch!("ga:users") |> parse_number(),
      visits: row.metrics |> Map.fetch!("ga:sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("ga:bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("ga:sessionDuration") |> parse_number()
    }
  end

  defp new_from_google_analytics(site_id, "imported_devices", row) do
    %{
      site_id: site_id,
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

  defp new_from_google_analytics(site_id, "imported_browsers", row) do
    browser = Map.fetch!(row.dimensions, "ga:browser")

    %{
      site_id: site_id,
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

  defp new_from_google_analytics(site_id, "imported_operating_systems", row) do
    os = Map.fetch!(row.dimensions, "ga:operatingSystem")

    %{
      site_id: site_id,
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

  @missing_values ["(none)", "(not set)", "(not provided)"]
  def nil_if_missing(value) when value in @missing_values, do: nil
  def nil_if_missing(value), do: value

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
