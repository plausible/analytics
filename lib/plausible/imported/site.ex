defmodule Plausible.Imported do
  alias Plausible.Imported

  def forget(site) do
    Plausible.ClickhouseRepo.clear_imported_stats_for(site.domain)
  end

  def from_google_analytics(data, domain, metric) do
    maybe_error =
      data
      |> Enum.map(fn row ->
        new_from_google_analytics(domain, metric, row)
        |> Plausible.ClickhouseRepo.insert(on_conflict: :replace_all)
      end)
      |> Keyword.get(:error)

    case maybe_error do
      nil ->
        {:ok, nil}

      error ->
        {:error, error}
    end
  end

  defp new_from_google_analytics(domain, "visitors", %{
         "dimensions" => [timestamp],
         "metrics" => [%{"values" => values}]
       }) do
    [visitors, pageviews, bounces, visits, visit_duration] =
      values
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(&elem(&1, 0))

    Imported.Visitors.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      visitors: visitors,
      pageviews: pageviews,
      bounces: bounces,
      visits: visits,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(domain, "sources", %{
         "dimensions" => [timestamp, source],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    source = if source == "(direct)", do: nil, else: source

    Imported.Sources.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      source: Imported.Sources.parse(source),
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  # TODO: utm_sources. Google reports sources and utm_sources unified.

  defp new_from_google_analytics(domain, "utm_mediums", %{
         "dimensions" => [timestamp, medium],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    medium = if medium == "(none)", do: "", else: medium

    Imported.UtmMediums.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      medium: medium,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(domain, "utm_campaigns", %{
         "dimensions" => [timestamp, campaign],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    campaign = if campaign == "(not set)", do: "", else: campaign

    Imported.UtmCampaigns.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      campaign: campaign,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(domain, "utm_terms", %{
         "dimensions" => [timestamp, term],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    term = if term == "(not set)" or term == "(not provided)", do: "", else: term

    Imported.UtmTerms.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      utm_term: term,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(domain, "utm_content", %{
         "dimensions" => [timestamp, content],
         "metrics" => [%{"values" => [visitors, visits, bounces, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {visits, ""} = Integer.parse(visits)
    {bounces, ""} = Integer.parse(bounces)
    {visit_duration, _} = Integer.parse(visit_duration)

    content = if content == "(not set)", do: "", else: content

    Imported.UtmContent.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      utm_content: content,
      visitors: visitors,
      visits: visits,
      bounces: bounces,
      visit_duration: visit_duration
    })
  end

  defp new_from_google_analytics(domain, "pages", %{
         "dimensions" => [timestamp, page],
         "metrics" => [%{"values" => [value, pageviews, time_on_page]}]
       }) do
    {visitors, ""} = Integer.parse(value)
    {pageviews, ""} = Integer.parse(pageviews)
    {time_on_page, _} = Integer.parse(time_on_page)

    Imported.Pages.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      page: page,
      visitors: visitors,
      pageviews: pageviews,
      time_on_page: time_on_page
    })
  end

  defp new_from_google_analytics(domain, "entry_pages", %{
         "dimensions" => [timestamp, entry_page],
         "metrics" => [%{"values" => [visitors, entrances, visit_duration, bounces]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {entrances, ""} = Integer.parse(entrances)
    {bounces, ""} = Integer.parse(bounces)

    {visit_duration, _} = Integer.parse(visit_duration)

    Imported.EntryPages.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      entry_page: entry_page,
      visitors: visitors,
      entrances: entrances,
      visit_duration: visit_duration,
      bounces: bounces
    })
  end

  defp new_from_google_analytics(domain, "exit_pages", %{
         "dimensions" => [timestamp, exit_page],
         "metrics" => [%{"values" => [value, exits]}]
       }) do
    {visitors, ""} = Integer.parse(value)
    {exits, ""} = Integer.parse(exits)

    Imported.ExitPages.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      exit_page: exit_page,
      visitors: visitors,
      exits: exits
    })
  end

  defp new_from_google_analytics(domain, "locations", %{
         "dimensions" => [timestamp, country, region],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)
    country = if country == "(not set)", do: "", else: country
    region = if region == "(not set)", do: "", else: region

    Imported.Locations.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      country: country,
      region: region,
      city: 0,
      visitors: visitors
    })
  end

  defp new_from_google_analytics(domain, "devices", %{
         "dimensions" => [timestamp, device],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.Devices.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      device: String.capitalize(device),
      visitors: visitors
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

  defp new_from_google_analytics(domain, "browsers", %{
         "dimensions" => [timestamp, browser],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.Browsers.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      browser: Map.get(@browser_google_to_plausible, browser, browser),
      visitors: visitors
    })
  end

  @os_google_to_plausible %{
    "Macintosh" => "Mac",
    "Linux" => "GNU/Linux",
    "(not set)" => ""
  }

  defp new_from_google_analytics(domain, "operating_systems", %{
         "dimensions" => [timestamp, operating_system],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.OperatingSystems.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      operating_system: Map.get(@os_google_to_plausible, operating_system, operating_system),
      visitors: visitors
    })
  end

  defp format_timestamp(timestamp) do
    Timex.Parse.DateTime.Parser.parse!(timestamp, "{YYYY}{M}{D}")
  end
end
