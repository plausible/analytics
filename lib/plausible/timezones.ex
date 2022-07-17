defmodule Plausible.Timezones do
  def options do
    Tzdata.zone_list()
    |> Enum.map(&build_option/1)
    |> Enum.sort_by(& &1[:offset], :desc)
  end

  defp build_option(timezone_code) do
    timezone_info = Timex.Timezone.get(timezone_code)
    offset_in_minutes = div(timezone_info.offset_utc, -60)

    hhmm_formatted_offset =
      timezone_info
      |> Timex.TimezoneInfo.format_offset()
      |> String.slice(0..-4)

    [
      key: "(GMT#{hhmm_formatted_offset}) #{timezone_code}",
      value: timezone_code,
      offset: offset_in_minutes
    ]
  end
end
