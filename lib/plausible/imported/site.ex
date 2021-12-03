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
    [visitors, pageviews, bounce_rate, avg_session_duration] =
      values
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(&elem(&1, 0))

    Imported.Visitors.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      visitors: visitors,
      pageviews: pageviews,
      bounce_rate: bounce_rate,
      avg_visit_duration: avg_session_duration
    })
  end

  defp new_from_google_analytics(domain, "sources", %{
         "dimensions" => [timestamp, source],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    source = if source == "(direct)", do: "", else: source

    Imported.Sources.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      source: source,
      visitors: visitors
    })
  end

  # TODO: utm_sources. Google reports sources and utm_sources unified.

  defp new_from_google_analytics(domain, "utm_mediums", %{
         "dimensions" => [timestamp, medium],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    medium = if medium == "(none)", do: "", else: medium

    Imported.UtmMediums.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      medium: medium,
      visitors: visitors
    })
  end

  defp new_from_google_analytics(domain, "utm_campaigns", %{
         "dimensions" => [timestamp, campaign],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    campaign = if campaign == "(not set)", do: "", else: campaign

    Imported.UtmCampaigns.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      campaign: campaign,
      visitors: visitors
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
         "metrics" => [%{"values" => [visitors, entrances, visit_duration]}]
       }) do
    {visitors, ""} = Integer.parse(visitors)
    {entrances, ""} = Integer.parse(entrances)

    {visit_duration, _} = Integer.parse(visit_duration)

    Imported.EntryPages.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      entry_page: entry_page,
      visitors: visitors,
      entrances: entrances,
      visit_duration: visit_duration
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

  defp new_from_google_analytics(domain, "countries", %{
         "dimensions" => [timestamp, country, region, city],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.Locations.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      country: country,
      region: region,
      city: city,
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

  defp new_from_google_analytics(domain, "browsers", %{
         "dimensions" => [timestamp, browser],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.Browsers.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      browser: browser,
      visitors: visitors
    })
  end

  defp new_from_google_analytics(domain, "operating_systems", %{
         "dimensions" => [timestamp, os],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.OperatingSystems.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      operating_system: os,
      visitors: visitors
    })
  end

  defp format_timestamp(timestamp) do
    {year, monthday} = String.split_at(timestamp, 4)
    {month, day} = String.split_at(monthday, 2)

    [year, month, day]
    |> Enum.map(&Kernel.elem(Integer.parse(&1), 0))
    |> List.to_tuple()
    |> (&NaiveDateTime.from_erl!({&1, {12, 0, 0}})).()
  end
end
