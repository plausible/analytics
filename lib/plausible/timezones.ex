defmodule Plausible.Timezones do
  @spec options(DateTime.t()) :: [{:key, String.t()}, {:value, String.t()}, {:offset, integer()}]
  def options(now \\ DateTime.utc_now()) do
    Tzdata.zone_list()
    |> Enum.reduce([], fn timezone_code, acc -> build_option(timezone_code, acc, now) end)
    |> Enum.sort_by(& &1[:offset], :desc)
  end

  @spec to_utc_datetime(NaiveDateTime.t(), String.t()) :: DateTime.t()
  def to_utc_datetime(naive_date_time, timezone) do
    case Timex.to_datetime(naive_date_time, timezone) do
      %DateTime{} = tz_dt ->
        Timex.Timezone.convert(tz_dt, "UTC")

      %Timex.AmbiguousDateTime{after: after_dt} ->
        Timex.Timezone.convert(after_dt, "UTC")

      {:error, {:could_not_resolve_timezone, _, _, _}} ->
        Timex.Timezone.convert(naive_date_time, "UTC")
    end
  end

  @spec to_date_in_timezone(Date.t() | NaiveDateTime.t() | DateTime.t(), String.t()) :: Date.t()
  def to_date_in_timezone(dt, timezone) do
    utc_dt = Timex.Timezone.convert(dt, "UTC")

    case Timex.Timezone.convert(utc_dt, timezone) do
      %DateTime{} = tz_dt ->
        Timex.to_date(tz_dt)

      %Timex.AmbiguousDateTime{after: after_dt} ->
        Timex.to_date(after_dt)

      {:error, {:could_not_resolve_timezone, _, _, _}} ->
        dt
    end
  end

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
