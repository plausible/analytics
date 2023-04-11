defmodule Plausible.Imported do
  use Plausible.ClickhouseRepo
  use Timex
  require Logger

  @missing_values ["(none)", "(not set)", "(not provided)", "(other)"]

  @tables ~w(
    imported_visitors imported_sources imported_pages imported_entry_pages
    imported_exit_pages imported_locations imported_devices imported_browsers
    imported_operating_systems
  )
  @spec tables() :: [String.t()]
  def tables, do: @tables

  def forget(site) do
    Plausible.Purge.delete_imported_stats!(site)
  end

  def from_google_analytics(nil, _site_id, _metric), do: nil

  def from_google_analytics(data, site_id, table) do
    Enum.reduce(data, [], fn row, acc ->
      if Map.get(row.dimensions, "ga:date") in @missing_values do
        acc
      else
        [new_from_google_analytics(site_id, table, row) | acc]
      end
    end)
  end

  defp parse_number(nr) do
    {float, ""} = Float.parse(nr)
    round(float)
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
    country_code = row.dimensions |> Map.fetch!("ga:countryIsoCode") |> default_if_missing("")
    city_name = row.dimensions |> Map.fetch!("ga:city") |> default_if_missing("")
    city_data = Location.get_city(city_name, country_code)

    %{
      site_id: site_id,
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
