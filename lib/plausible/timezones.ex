defmodule Plausible.Timezones do
  @spec options(DateTime.t()) :: [{:key, String.t()}, {:value, String.t()}, {:offset, integer()}]
  def options(now \\ DateTime.utc_now()) do
    Tzdata.zone_list()
    |> Enum.reduce([], fn timezone_code, acc -> build_option(timezone_code, acc, now) end)
    |> Enum.sort_by(& &1[:offset], :desc)
  end

  defp build_option(timezone_code, acc, now) do
    case Timex.Timezone.get(timezone_code, now) do
      %Timex.TimezoneInfo{} = timezone_info ->
        offset_in_minutes = timezone_info |> Timex.Timezone.total_offset() |> div(-60)

        hhmm_formatted_offset =
          timezone_info
          |> Timex.TimezoneInfo.format_offset()
          |> String.slice(0..-4)

        option = [
          key: "(GMT#{hhmm_formatted_offset}) #{timezone_code}",
          value: timezone_code,
          offset: offset_in_minutes
        ]

        [option | acc]

      error ->
        Sentry.capture_message("Failed to fetch timezone",
          extra: %{code: timezone_code, error: inspect(error)}
        )

        acc
    end
  end
end
