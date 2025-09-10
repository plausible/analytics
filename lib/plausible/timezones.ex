defmodule Plausible.Timezones do
  @moduledoc """
  API for working with timezones wrapping around external libraries where necessary.
  """

  @spec options(DateTime.t()) :: [{:key, String.t()}, {:value, String.t()}, {:offset, integer()}]
  def options(now \\ DateTime.utc_now()) do
    Tzdata.zone_list()
    |> Enum.reduce([], fn timezone_code, acc -> build_option(timezone_code, acc, now) end)
    |> Enum.sort_by(& &1[:offset], :desc)
  end

  @spec to_date_in_timezone(Date.t() | NaiveDateTime.t() | DateTime.t(), String.t()) :: Date.t()
  def to_date_in_timezone(dt, timezone) do
    to_datetime_in_timezone(dt, timezone) |> DateTime.to_date()
  end

  @spec to_datetime_in_timezone(Date.t() | NaiveDateTime.t() | DateTime.t(), String.t()) ::
          DateTime.t()
  def to_datetime_in_timezone(dt, timezone) do
    dt |> to_datetime() |> DateTime.shift_zone!(timezone)
  end

  defp to_datetime(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")
  defp to_datetime(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  defp to_datetime(%DateTime{} = already_dt), do: already_dt

  defp build_option(timezone_code, acc, now) do
    case Timex.Timezone.get(timezone_code, now) do
      %Timex.TimezoneInfo{} = timezone_info ->
        offset_in_minutes = timezone_info |> Timex.Timezone.total_offset() |> div(-60)

        hhmm_formatted_offset =
          timezone_info
          |> Timex.TimezoneInfo.format_offset()
          |> String.slice(0..-4//1)

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
