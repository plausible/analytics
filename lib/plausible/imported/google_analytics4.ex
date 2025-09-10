defmodule Plausible.Imported.GoogleAnalytics4 do
  @moduledoc """
  Import implementation for Google Analytics 4.
  """

  use Plausible.Imported.Importer

  alias Plausible.Imported
  alias Plausible.Repo

  @recoverable_errors [:rate_limit_exceeded, :socket_failed, :server_failed]
  @missing_values ["(none)", "(not set)", "(not provided)", "(other)"]

  @impl true
  def name(), do: :google_analytics_4

  @impl true
  def label(), do: "Google Analytics 4"

  @impl true
  def email_template(), do: "google_analytics_import.html"

  @impl true
  def before_start(site_import, opts) do
    site_import = Repo.preload(site_import, :site)

    if import_id = Keyword.get(opts, :resume_from_import_id) do
      if existing_site_import = Imported.get_import(site_import.site, import_id) do
        Repo.delete!(site_import)
        {:ok, existing_site_import}
      else
        # NOTE: shouldn't happen under normal circumsatnces
        {:error, {:no_import_to_resume, import_id}}
      end
    else
      {:ok, site_import}
    end
  end

  @impl true
  def parse_args(%{"resume_from_dataset" => dataset, "resume_from_offset" => offset} = args) do
    args
    |> Map.drop(["resume_from_dataset", "resume_from_offset"])
    |> parse_args()
    |> Keyword.put(:dataset, dataset)
    |> Keyword.put(:offset, offset)
  end

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
    flush_interval_ms = Keyword.get(opts, :flush_interval_ms, 1000)

    {:ok, buffer} = Plausible.Imported.Buffer.start_link(flush_interval_ms: flush_interval_ms)

    persist_fn = fn table, rows ->
      records = from_report(rows, site_import.site_id, site_import.id, table)
      Plausible.Imported.Buffer.insert_many(buffer, table, records)
    end

    resume_opts = Keyword.take(opts, [:dataset, :offset])
    fetch_opts = Keyword.get(opts, :fetch_opts, [])

    try do
      result =
        Plausible.Google.GA4.API.import_analytics(date_range, property, auth,
          persist_fn: persist_fn,
          fetch_opts: fetch_opts,
          resume_opts: resume_opts
        )

      case result do
        {:error, {error, details}} when error in @recoverable_errors ->
          site_import = Repo.preload(site_import, [:site, :imported_by])
          dataset = Keyword.fetch!(details, :dataset)
          offset = Keyword.fetch!(details, :offset)
          {access_token, refresh_token, token_expires_at} = auth

          resume_import_opts = [
            property: property,
            label: property,
            start_date: date_range.first,
            end_date: date_range.last,
            access_token: access_token,
            refresh_token: refresh_token,
            token_expires_at: token_expires_at,
            resume_from_import_id: site_import.id,
            resume_from_dataset: dataset,
            resume_from_offset: offset,
            job_opts: [schedule_in: {65, :minutes}, unique: nil]
          ]

          new_import(
            site_import.site,
            site_import.imported_by,
            resume_import_opts
          )

          {:error, error, skip_purge?: true, skip_mark_failed?: true}

        other ->
          other
      end
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

  defp maybe_override_event_name("file_download"), do: "File Download"
  defp maybe_override_event_name("click"), do: "Outbound Link: Click"
  defp maybe_override_event_name(name), do: name

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
      source: row.dimensions |> Map.fetch!("sessionSource") |> parse_source(),
      # GA4 channels map 1-1 to Plausible channels
      channel: row.dimensions |> Map.fetch!("sessionDefaultChannelGroup"),
      referrer: nil,
      # Only `source` exists in GA4 API
      utm_source: nil,
      utm_medium: row.dimensions |> Map.fetch!("sessionMedium") |> default_if_missing(),
      utm_campaign: row.dimensions |> Map.fetch!("sessionCampaignName") |> default_if_missing(),
      utm_content: row.dimensions |> Map.fetch!("sessionManualAdContent") |> default_if_missing(),
      utm_term: row.dimensions |> Map.fetch!("sessionGoogleAdsKeyword") |> default_if_missing(),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
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
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
      # NOTE: no exits metric in GA4 API currently
      exits: 0,
      total_time_on_page: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number(),
      total_time_on_page_visits: row.metrics |> Map.fetch!("sessions") |> parse_number()
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
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
      bounces: row.metrics |> Map.fetch!("bounces") |> parse_number()
    }
  end

  # NOTE: no exit pages metrics in GA4 API available for now
  # defp new_from_report(site_id, import_id, "imported_exit_pages", row) do
  #   %{
  #     site_id: site_id,
  #     import_id: import_id,
  #     date: get_date(row),
  #     exit_page: Map.fetch!(row.dimensions, "exitPage"),
  #     visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
  #     exits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
  #     visit_duration: row.metrics |> Map.fetch!("userEngagementDuration") |> parse_number(),
  #     pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
  #     bounces: row.metrics |> Map.fetch!("bounces") |> parse_number()
  #   }
  # end

  defp new_from_report(site_id, import_id, "imported_custom_events", row) do
    %{
      site_id: site_id,
      import_id: import_id,
      date: get_date(row),
      name: row.dimensions |> Map.fetch!("eventName") |> maybe_override_event_name(),
      link_url: row.dimensions |> Map.fetch!("linkUrl"),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      events: row.metrics |> Map.fetch!("eventCount") |> parse_number()
    }
  end

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
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
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
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
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
      # Does not exist in GA4 API
      browser_version: nil,
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
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
      operating_system_version: row.dimensions |> Map.fetch!("operatingSystemVersion"),
      visitors: row.metrics |> Map.fetch!("totalUsers") |> parse_number(),
      visits: row.metrics |> Map.fetch!("sessions") |> parse_number(),
      pageviews: row.metrics |> Map.fetch!("screenPageViews") |> parse_number(),
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

  defp parse_source(nil), do: nil
  defp parse_source("(direct)"), do: nil
  defp parse_source("google"), do: "Google"
  defp parse_source("bing"), do: "Bing"
  defp parse_source("duckduckgo"), do: "DuckDuckGo"

  defp parse_source(ref) do
    Plausible.Ingestion.Source.parse("https://" <> ref)
  end
end
