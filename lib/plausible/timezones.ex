defmodule Plausible.Timezones do
  @spec options(DateTime.t()) :: [{:key, String.t()}, {:value, String.t()}, {:offset, integer()}]
  def options(now \\ DateTime.utc_now()) do
    Tzdata.zone_list()
    |> Enum.reduce([], fn timezone_code, acc -> build_option(timezone_code, acc, now) end)
    |> Enum.sort_by(& &1[:offset], :desc)
  end

  @doc """
  Represents wall time as Etc/UTC.

      iex> to_utc_datetime(~N[2024-03-16 09:50:45], "Asia/Kuala_Lumpur")
      ~U[2024-03-16 01:50:45Z]

  When wall time is ambiguous - for instance during changing from summer to winter time -
  the larger Etc/UTC timestamp is returned by default.

      # before the CEST -> CET overlap
      iex> to_utc_datetime(~N[2018-10-28 01:59:59], "Europe/Copenhagen")
      ~U[2018-10-27 23:59:59Z]

      # during
      iex> to_utc_datetime(~N[2018-10-28 02:00:00], "Europe/Copenhagen")
      ~U[2018-10-28 01:00:00Z]

      iex> to_utc_datetime(~N[2018-10-28 02:00:00], "Europe/Copenhagen", :up)
      ~U[2018-10-28 01:00:00Z]

      iex> to_utc_datetime(~N[2018-10-28 02:00:00], "Europe/Copenhagen", :down)
      ~U[2018-10-28 00:00:00Z]

      iex> to_utc_datetime(~N[2018-10-28 02:30:00], "Europe/Copenhagen")
      ~U[2018-10-28 01:30:00Z]

      # after
      iex> to_utc_datetime(~N[2018-10-28 03:00:00], "Europe/Copenhagen")
      ~U[2018-10-28 02:00:00Z]

  When there is a gap in wall time - for instance in spring when the clocks are turned forward -
  the larger Etc/UTC timestamp (at the end of the gap) is returned by default as well.

      # before the CET -> CEST gap
      iex> to_utc_datetime(~N[2019-03-31 01:59:59], "Europe/Copenhagen")
      ~U[2019-03-31 00:59:59Z]

      # during
      iex> to_utc_datetime(~N[2019-03-31 02:00:00], "Europe/Copenhagen")
      ~U[2019-03-31 01:00:00Z]

      iex> to_utc_datetime(~N[2019-03-31 02:30:00], "Europe/Copenhagen", :up)
      ~U[2019-03-31 01:00:00Z]

      iex> to_utc_datetime(~N[2019-03-31 02:30:00], "Europe/Copenhagen", :down)
      ~U[2019-03-31 00:59:59.999999Z]

      # after
      iex> to_utc_datetime(~N[2019-03-31 03:00:00], "Europe/Copenhagen")
      ~U[2019-03-31 01:00:00Z]

  If the supplied time zone is invalid, the wall time is assumed to be Etc/UTC.

      iex> to_utc_datetime(~N[2024-03-16 09:50:45], "Europe/Asia")
      ~U[2024-03-16 09:50:45Z]

  """
  @spec to_utc_datetime(NaiveDateTime.t(), String.t(), :up | :down) :: DateTime.t()
  def to_utc_datetime(naive_date_time, timezone, direction \\ :up) do
    case DateTime.from_naive(naive_date_time, timezone) do
      {:ok, date_time} ->
        DateTime.shift_zone!(date_time, "Etc/UTC")

      {:gap, before_dt, after_dt} ->
        DateTime.shift_zone!(pick_datetime(direction, before_dt, after_dt), "Etc/UTC")

      {:ambiguous, first_dt, second_dt} ->
        DateTime.shift_zone!(pick_datetime(direction, first_dt, second_dt), "Etc/UTC")

      {:error, :time_zone_not_found} ->
        DateTime.from_naive!(naive_date_time, "Etc/UTC")
    end
  end

  defp pick_datetime(:up, _, dt), do: dt
  defp pick_datetime(:down, dt, _), do: dt

  @doc """
  Same as `to_datetime_in_timezone/2` but extracts the date from the result.

      iex> to_date_in_timezone(~N[2024-03-16 01:50:45], "Asia/Kuala_Lumpur")
      ~D[2024-03-16]

  """
  @spec to_date_in_timezone(NaiveDateTime.t() | DateTime.t() | Date.t(), String.t()) :: Date.t()
  def to_date_in_timezone(dt, timezone) do
    dt |> to_datetime_in_timezone(timezone) |> DateTime.to_date()
  end

  @doc """
  Represents a timestamp in a different timezone.
  Naive datetimes are assumed to be in Etc/UTC timezone.
  Dates are assumed to mean a Etc/UTC midnight.

      iex> to_datetime_in_timezone(~N[2024-03-16 01:50:45], "Asia/Kuala_Lumpur")
      #DateTime<2024-03-16 09:50:45+08:00 +08 Asia/Kuala_Lumpur>

      # see https://stackoverflow.com/questions/53076575/time-zones-etc-gmt-why-it-is-other-way-round
      iex> to_datetime_in_timezone(~N[2024-03-16 01:50:45], "Etc/GMT-8")
      #DateTime<2024-03-16 09:50:45+08:00 +08 Etc/GMT-8>

      iex> to_datetime_in_timezone(~N[2024-03-16 01:50:45], "GMT+8")
      #DateTime<2024-03-16 09:50:45+08:00 +08 GMT+8>

      iex> to_datetime_in_timezone(~D[2018-10-28], "Europe/Copenhagen")
      #DateTime<2018-10-28 02:00:00+02:00 CEST Europe/Copenhagen>

  """
  @spec to_datetime_in_timezone(NaiveDateTime.t() | DateTime.t() | Date.t(), String.t()) ::
          DateTime.t()
  def to_datetime_in_timezone(%NaiveDateTime{} = naive, timezone) do
    naive
    |> DateTime.from_naive!("Etc/UTC")
    |> to_datetime_in_timezone(timezone)
  end

  def to_datetime_in_timezone(%Date{} = date, timezone) do
    date
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    |> to_datetime_in_timezone(timezone)
  end

  def to_datetime_in_timezone(%DateTime{} = dt, timezone) do
    DateTime.shift_zone!(dt, timezone)
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
