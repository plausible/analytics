defmodule Plausible.Imported do
  alias Plausible.Imported
  use Timex

  def forget(site) do
    Plausible.ClickhouseRepo.clear_imported_stats_for(site.id)
  end

  def from_google_analytics(nil, _site_id, _metric, _timezone), do: {:ok, nil}

  def from_google_analytics(data, site_id, metric, timezone) do
    maybe_error =
      data
      |> Enum.map(fn row ->
        new_from_google_analytics(site_id, timezone, metric, row)
        |> Plausible.ClickhouseRepo.insert(on_conflict: :replace_all)
      end)
      |> Keyword.get(:error)

    case maybe_error do
      nil ->
        {:ok, nil}

      error ->
        {:error, error.errors}
    end
  end

  defp new_from_google_analytics(site_id, timezone, "visitors", %{
         "dimensions" => [timestamp],
         "metrics" => [%{"values" => values}]
       }) do
    [visitors, pageviews, bounces, visits, visit_duration] =
      values
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(&elem(&1, 0))

    Imported.Visitors.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      visitors: visitors,
      pageviews: pageviews,
      bounces: bounces,
      visits: visits,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(site_id, timezone, "sources", %{
         "dimensions" => [timestamp, source],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    source = if source == "(direct)", do: nil, else: source

    Imported.Sources.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      source: Imported.Sources.parse(source),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  # TODO: utm_sources. Google reports sources and utm_sources unified.

  defp new_from_google_analytics(site_id, timezone, "utm_mediums", %{
         "dimensions" => [timestamp, medium],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    medium = if medium == "(none)", do: "", else: medium

    Imported.UtmMediums.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      utm_medium: medium,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(site_id, timezone, "utm_campaigns", %{
         "dimensions" => [timestamp, campaign],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    campaign = if campaign == "(not set)", do: "", else: campaign

    Imported.UtmCampaigns.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      utm_campaign: campaign,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(site_id, timezone, "utm_terms", %{
         "dimensions" => [timestamp, term],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    term = if term == "(not set)" or term == "(not provided)", do: "", else: term

    Imported.UtmTerms.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      utm_term: term,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(site_id, timezone, "utm_contents", %{
         "dimensions" => [timestamp, content],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    content = if content == "(not set)", do: "", else: content

    Imported.UtmContents.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      utm_content: content,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(site_id, timezone, "pages", %{
         "dimensions" => [timestamp, page],
         "metrics" => [%{"values" => [visitors, pageviews, time_on_page]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {pageviews, ""} = Integer.parse(pageviews)
    {time_on_page, _} = Integer.parse(time_on_page)

    Imported.Pages.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      page: page,
      visitors: visitors,
      pageviews: pageviews,
      time_on_page: time_on_page
    })
  end

  defp new_from_google_analytics(site_id, timezone, "entry_pages", %{
         "dimensions" => [timestamp, entry_page],
         "metrics" => [%{"values" => [visitors, entrances, visit_duration, bounces]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {entrances, ""} = Integer.parse(entrances)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    Imported.EntryPages.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      entry_page: entry_page,
      visitors: visitors,
      entrances: entrances,
      visit_duration: visit_duration,
      bounces: bounces
    })
  end

  defp new_from_google_analytics(site_id, timezone, "exit_pages", %{
         "dimensions" => [timestamp, exit_page],
         "metrics" => [%{"values" => [visitors, exits]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {exits, ""} = Integer.parse(exits)

    Imported.ExitPages.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      exit_page: exit_page,
      visitors: visitors,
      exits: exits
    })
  end

  defp new_from_google_analytics(site_id, timezone, "locations", %{
         "dimensions" => [timestamp, country, region],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    country = if country == "(not set)", do: "", else: country
    region = if region == "(not set)", do: "", else: region
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    Imported.Locations.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      country: country,
      region: region,
      city: 0,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(site_id, timezone, "devices", %{
         "dimensions" => [timestamp, device],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    Imported.Devices.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      device: String.capitalize(device),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
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

  defp new_from_google_analytics(site_id, timezone, "browsers", %{
         "dimensions" => [timestamp, browser],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    Imported.Browsers.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      browser: Map.get(@browser_google_to_plausible, browser, browser),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  @os_google_to_plausible %{
    "Macintosh" => "Mac",
    "Linux" => "GNU/Linux",
    "(not set)" => ""
  }

  defp new_from_google_analytics(site_id, timezone, "operating_systems", %{
         "dimensions" => [timestamp, operating_system],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    Imported.OperatingSystems.new(%{
      site_id: site_id,
      timestamp: format_timestamp(timestamp, timezone),
      operating_system: Map.get(@os_google_to_plausible, operating_system, operating_system),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp format_timestamp(timestamp, timezone) do
    Timex.parse!("#{timestamp}", "%Y%m%d%H", :strftime)
    |> Timezone.convert(timezone)
    |> Timezone.convert("UTC")
    |> DateTime.to_naive()
  end
end
