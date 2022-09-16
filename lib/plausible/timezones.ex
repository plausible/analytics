defmodule Plausible.Timezones do
  @spec options() :: [{:key, String.t()}, {:value, String.t()}, {:offset, integer()}]
  def options do
    Tzdata.zone_list()
    |> Enum.map(&build_option/1)
    |> Enum.sort_by(& &1[:offset], :desc)
  end

  defp build_option(timezone_code) do
    timezone_info = Timex.Timezone.get(timezone_code)
    offset_in_minutes = timezone_info |> Timex.Timezone.total_offset() |> div(-60)

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
