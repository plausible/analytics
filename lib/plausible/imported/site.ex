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
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.Pages.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      page: page,
      visitors: visitors
    })
  end

  defp new_from_google_analytics(domain, "entry_pages", %{
         "dimensions" => [timestamp, entry_page],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.EntryPages.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      entry_page: entry_page,
      visitors: visitors
    })
  end

  defp new_from_google_analytics(domain, "exit_pages", %{
         "dimensions" => [timestamp, exit_page],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.ExitPages.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      exit_page: exit_page,
      visitors: visitors
    })
  end

  defp new_from_google_analytics(domain, "countries", %{
         "dimensions" => [timestamp, country],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.Countries.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      country: country,
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
      device: device,
      visitors: visitors
    })
  end

  defp new_from_google_analytics(domain, "browsers", %{
         "dimensions" => [timestamp, browser, version],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.Browsers.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      browser: browser,
      version: version,
      visitors: visitors
    })
  end

  defp new_from_google_analytics(domain, "operating_systems", %{
         "dimensions" => [timestamp, os, version],
         "metrics" => [%{"values" => [value]}]
       }) do
    {visitors, ""} = Integer.parse(value)

    Imported.OperatingSystems.new(%{
      domain: domain,
      timestamp: format_timestamp(timestamp),
      operating_system: os,
      version: version,
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
