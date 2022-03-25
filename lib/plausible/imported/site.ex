defmodule Plausible.Imported do
  use Plausible.ClickhouseRepo
  use Timex
  require Logger

  def forget(site) do
    Plausible.ClickhouseRepo.clear_imported_stats_for(site.id)
  end

  def from_google_analytics(nil, _site_id, _metric), do: {:ok, nil}

  def from_google_analytics(data, site_id, table) do
    Logger.debug("Processing imported data (table=#{table}): #{inspect(data)}")

    data =
      Enum.map(data, fn row ->
        new_from_google_analytics(site_id, table, row)
      end)

    case ClickhouseRepo.insert_all(table, data) do
      {n_rows, _} when n_rows > 0 -> :ok
      error -> error
    end
  end

  defp new_from_google_analytics(site_id, "imported_visitors", %{
         "dimensions" => [date],
         "metrics" => [%{"values" => values}]
       }) do
    [visitors, pageviews, bounces, visits, visit_duration] =
      values
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(&elem(&1, 0))

    %{
      site_id: site_id,
      date: format_date(date),
      visitors: visitors,
      pageviews: pageviews,
      bounces: bounces,
      visits: visits,
      visit_duration: visit_duration
    }
  end

  # Credit: https://github.com/kvesteri/validators
  @domain ~r/^(([a-zA-Z]{1})|([a-zA-Z]{1}[a-zA-Z]{1})|([a-zA-Z]{1}[0-9]{1})|([0-9]{1}[a-zA-Z]{1})|([a-zA-Z0-9][-_.a-zA-Z0-9]{0,61}[a-zA-Z0-9]))\.([a-zA-Z]{2,13}|[a-zA-Z0-9-]{2,30}.[a-zA-Z]{2,3})$/

  defp new_from_google_analytics(site_id, "imported_sources", %{
         "dimensions" => [date, source, medium, campaign, content, term],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    source = if source == "(direct)", do: nil, else: source
    source = if source && String.match?(source, @domain), do: parse_referrer(source), else: source

    %{
      site_id: site_id,
      date: format_date(date),
      source: parse_referrer(source),
      utm_medium: nil_if_missing(medium),
      utm_campaign: nil_if_missing(campaign),
      utm_content: nil_if_missing(content),
      utm_term: nil_if_missing(term),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    }
  end

  defp new_from_google_analytics(site_id, "imported_pages", %{
         "dimensions" => [date, hostname, page],
         "metrics" => [%{"values" => [visitors, pageviews, exits, time_on_page]}]
       }) do
    page = URI.parse(page).path
    {visitors, ""} = Integer.parse(visitors)
    {pageviews, ""} = Integer.parse(pageviews)
    {exits, ""} = Integer.parse(exits)
    {time_on_page, _} = Integer.parse(time_on_page)

    %{
      site_id: site_id,
      date: format_date(date),
      hostname: String.replace_prefix(hostname, "www.", ""),
      page: page,
      visitors: visitors,
      pageviews: pageviews,
      exits: exits,
      time_on_page: time_on_page
    }
  end

  defp new_from_google_analytics(site_id, "imported_entry_pages", %{
         "dimensions" => [date, entry_page],
         "metrics" => [%{"values" => [visitors, entrances, visit_duration, bounces]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {entrances, ""} = Integer.parse(entrances)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    %{
      site_id: site_id,
      date: format_date(date),
      entry_page: entry_page,
      visitors: visitors,
      entrances: entrances,
      visit_duration: visit_duration,
      bounces: bounces
    }
  end

  defp new_from_google_analytics(site_id, "imported_exit_pages", %{
         "dimensions" => [date, exit_page],
         "metrics" => [%{"values" => [visitors, exits]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {exits, ""} = Integer.parse(exits)

    %{
      site_id: site_id,
      date: format_date(date),
      exit_page: exit_page,
      visitors: visitors,
      exits: exits
    }
  end

  defp new_from_google_analytics(site_id, "imported_locations", %{
         "dimensions" => [date, country, region],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    country = if country == "(not set)", do: "", else: country
    region = if region == "(not set)", do: "", else: region
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    %{
      site_id: site_id,
      date: format_date(date),
      country: country,
      region: region,
      city: 0,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    }
  end

  defp new_from_google_analytics(site_id, "imported_devices", %{
         "dimensions" => [date, device],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    %{
      site_id: site_id,
      date: format_date(date),
      device: String.capitalize(device),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
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

  defp new_from_google_analytics(site_id, "imported_browsers", %{
         "dimensions" => [date, browser],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    %{
      site_id: site_id,
      date: format_date(date),
      browser: Map.get(@browser_google_to_plausible, browser, browser),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    }
  end

  @os_google_to_plausible %{
    "Macintosh" => "Mac",
    "Linux" => "GNU/Linux",
    "(not set)" => ""
  }

  defp new_from_google_analytics(site_id, "imported_operating_systems", %{
         "dimensions" => [date, operating_system],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    %{
      site_id: site_id,
      date: format_date(date),
      operating_system: Map.get(@os_google_to_plausible, operating_system, operating_system),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    }
  end

  defp format_date(date) do
    Timex.parse!("#{date}", "%Y%m%d", :strftime)
    |> NaiveDateTime.to_date()
  end

  @missing_values ["(none)", "(not set)", "(not provided)"]
  def nil_if_missing(value) when value in @missing_values, do: nil
  def nil_if_missing(value), do: value

  def parse_referrer(nil), do: nil
  def parse_referrer("google"), do: "Google"
  def parse_referrer("bing"), do: "Bing"
  def parse_referrer("duckduckgo"), do: "DuckDuckGo"

  def parse_referrer(ref) do
    RefInspector.parse("https://" <> ref)
    |> PlausibleWeb.RefInspector.parse()
  end
end
