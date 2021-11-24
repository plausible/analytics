defmodule Plausible.Imported do
  alias Plausible.Imported

  def forget(site) do
    Plausible.ClickhouseRepo.clear_imported_stats_for(site.domain)
  end

  def from_google_analytics(data, domain, metric) do
    maybe_error =
      data
      |> Enum.map(&new_from_google_analytics(domain, metric, &1))
      |> Enum.map(&Plausible.ClickhouseRepo.insert(&1, on_conflict: :replace_all))
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

  defp format_timestamp(timestamp) do
    {year, monthday} = String.split_at(timestamp, 4)
    {month, day} = String.split_at(monthday, 2)

    [year, month, day]
    |> Enum.map(&Kernel.elem(Integer.parse(&1), 0))
    |> List.to_tuple()
    |> (&NaiveDateTime.from_erl!({&1, {12, 0, 0}})).()
  end
end
