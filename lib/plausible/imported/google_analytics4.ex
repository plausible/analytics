defmodule Plausible.Imported.GoogleAnalytics4 do
  @moduledoc """
  Import implementation for Google Analytics 4.
  """

  use Plausible.Imported.Importer

  @missing_values ["(none)", "(not set)", "(not provided)", "(other)"]

  @impl true
  def name(), do: :google_analytics_4

  @impl true
  def label(), do: "Google Analytics 4"

  @impl true
  def email_template(), do: "google_analytics_import.html"

  @impl true
  def parse_args(
        %{"property" => property, "start_date" => start_date, "end_date" => end_date} = args
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
      property: property,
      date_range: date_range,
      auth: auth
    ]
  end

  @doc """
  Imports stats from a Google Analytics 4 property to a Plausible site.

  This function fetches Google Analytics 4 reports which are then passed in batches
  to Clickhouse by the `Plausible.Imported.Buffer` process.
  """
  @impl true
  def import_data(site_import, opts) do
    date_range = Keyword.fetch!(opts, :date_range)
    property = Keyword.fetch!(opts, :property)
    auth = Keyword.fetch!(opts, :auth)

    {:ok, buffer} = Plausible.Imported.Buffer.start_link()

    persist_fn = fn table, rows ->
      records = from_report(rows, site_import.site_id, site_import.id, table)
      Plausible.Imported.Buffer.insert_many(buffer, table, records)
    end

    try do
      Plausible.Google.GA4.API.import_analytics(date_range, property, auth, persist_fn)
    after
      Plausible.Imported.Buffer.flush(buffer)
      Plausible.Imported.Buffer.stop(buffer)
    end
  end

  def from_report(nil, _site_id, _import_id, _metric), do: nil

  def from_report(data, site_id, import_id, table) do
    Enum.reduce(data, [], fn row, acc ->
      if Map.get(row.dimensions, "date") in @missing_values do
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
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("bounces") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_sources", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      source: row.dimensions |> Map.fetch!("sessionSource") |> parse_referrer(),
      utm_medium: row.dimensions |> Map.fetch!("sessionMedium") |> default_if_missing(),
      utm_campaign: row.dimensions |> Map.fetch!("sessionCampaignName") |> default_if_missing(),
      utm_content: row.dimensions |> Map.fetch!("sessionManualAdContent") |> default_if_missing(),
      utm_term: row.dimensions |> Map.fetch!("sessionGoogleAdsKeyword") |> default_if_missing(),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_pages", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      hostname: row.dimensions |> Map.fetch!("hostName") |> String.replace_prefix("www.", ""),
      page: row.dimensions |> Map.fetch!("pagePath") |> URI.parse() |> Map.get(:path),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
      # NOTE: no exits metric in GA4 API currently
      exits: 0,
      time_on_page: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_entry_pages", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      entry_page: row.dimensions |> Map.fetch!("landingPage"),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      entrances: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("bounces") |> parse_number()
    }
  end

  # NOTE: note exit pages metrics in GA4 API available for now
  # defp new_from_report(site_id, import_id, "imported_exit_pages", row) do
  #   %{
  #     site_id: site_id,
  #     import_id: import_id,
  #     date: get_date(row),
  #     exit_page: Map.fetch!(row.dimensions, "exitPage"),
  #     visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
  #     exits: row.metrics |> Map.fetch!("sessions") |> parse_number()
  #   }
  # end

  defp new_from_report(site_id, import_id, "imported_locations", row) do
    country_code = row.dimensions |> Map.fetch!("countryId") |> default_if_missing("")
    city_name = row.dimensions |> Map.fetch!("city") |> default_if_missing("")
    city_data = Location.get_city(city_name, country_code)

    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      country: country_code,
      region: row.dimensions |> Map.fetch!("region") |> default_if_missing(""),
      city: city_data && city_data.id,
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number()
    }
  end

  defp new_from_report(site_id, import_id, "imported_devices", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      device: row.dimensions |> Map.fetch!("deviceCategory") |> String.capitalize(),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number()
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
    browser = Map.fetch!(row.dimensions, "browser")

    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      browser: Map.get(@browser_google_to_plausible, browser, browser),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number()
    }
  end

  @os_google_to_plausible %{
    "Macintosh" => "Mac",
    "Linux" => "GNU/Linux",
    "(not set)" => ""
  }

  defp new_from_report(site_id, import_id, "imported_operating_systems", row) do
    os = Map.fetch!(row.dimensions, "operatingSystem")

    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      operating_system: Map.get(@os_google_to_plausible, os, os),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("bounces") |> parse_number(),
      visit_duration: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number()
    }
  end

  defp get_date(%{dimensions: %{"date" => date}}) do
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
