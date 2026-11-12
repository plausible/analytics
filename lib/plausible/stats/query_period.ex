defmodule Plausible.Stats.QueryPeriod do
  @moduledoc """
  Parses the `date_range` input of a stats query, and builds the time range
  that the query covers.
  """

  alias Plausible.Stats.{DateTimeRange, QueryError}
  alias Plausible.Times

  def parse_input_date_range("day"), do: {:ok, :day}
  def parse_input_date_range("24h"), do: {:ok, :"24h"}
  def parse_input_date_range("month"), do: {:ok, :month}
  def parse_input_date_range("year"), do: {:ok, :year}
  def parse_input_date_range("all"), do: {:ok, :all}

  def parse_input_date_range(shorthand) when is_binary(shorthand) do
    case Integer.parse(shorthand) do
      {n, "d"} when n > 0 and n <= 5_000 ->
        {:ok, {:last_n_days, n}}

      {n, "mo"} when n > 0 and n <= 100 ->
        {:ok, {:last_n_months, n}}

      _ ->
        {:error,
         %QueryError{code: :invalid_date_range, message: "Invalid date_range #{i(shorthand)}"}}
    end
  end

  def parse_input_date_range([from, to]) when is_binary(from) and is_binary(to) do
    case parse_date_strings(from, to) do
      {:ok, dates} -> {:ok, dates}
      {:error, _} -> parse_timestamp_strings(from, to)
    end
  end

  def parse_input_date_range(nil) do
    {:error,
     %QueryError{code: :invalid_date_range, message: "Required 'date_range' parameter missing"}}
  end

  def parse_input_date_range(unknown) do
    {:error, %QueryError{code: :invalid_date_range, message: "Invalid date_range #{i(unknown)}"}}
  end

  @doc """
  Same as `parse_input_date_range/1`, but also accepts the "realtime" and
  "realtime_30m" which are currently exclusive to dashboard queries.
  """
  def parse_dashboard_input_date_range("realtime"), do: {:ok, :realtime}
  def parse_dashboard_input_date_range("realtime_30m"), do: {:ok, :realtime_30m}
  def parse_dashboard_input_date_range(date_range), do: parse_input_date_range(date_range)

  @doc """
  Parses the `relative_date` that the dashboard sends. Returns `nil` when
  there is no `relative_date`.
  """
  def parse_relative_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} ->
        {:ok, date}

      _ ->
        {:error,
         %QueryError{code: :invalid_relative_date, message: "Failed to convert '#{date}' to date"}}
    end
  end

  def parse_relative_date(_), do: {:ok, nil}

  def parse_date_strings(from, to) do
    with {:ok, from_date} <- Date.from_iso8601(from),
         {:ok, to_date} <- Date.from_iso8601(to) do
      {:ok, {:date_range, from_date, to_date}}
    end
  end

  defp parse_timestamp_strings(from, to) do
    with {:ok, from_datetime, _offset} <- DateTime.from_iso8601(from),
         {:ok, to_datetime, _offset} <- DateTime.from_iso8601(to) do
      {:ok, {:datetime_range, from_datetime, to_datetime}}
    else
      _ ->
        {:error,
         %QueryError{code: :invalid_date_range, message: "Invalid date_range '#{i([from, to])}'."}}
    end
  end

  defp i(value), do: inspect(value, charlists: :as_lists)

  @doc """
  Same as `build_range_for_site/4`, but returns the range in UTC.
  """
  def build_utc_range_for_site(input_date_range, %Plausible.Site{} = site, relative_date, now) do
    input_date_range
    |> build_range_for_site(site, relative_date, now)
    |> DateTimeRange.to_timezone("Etc/UTC")
  end

  @doc """
  Resolves an `input_date_range` for the site and builds the corresponding
  `%DateTimeRange{}` anchored to the site's timezone.

  `relative_date` may be `nil`, in which case it defaults to today in the
  site's timezone.
  """
  def build_range_for_site(input_date_range, %Plausible.Site{} = site, relative_date, now) do
    relative_date = relative_date || Times.to_date(now, site.timezone)

    input_date_range
    |> resolve_input_date_range(site, relative_date)
    |> build_datetime_range(site.timezone, relative_date, now)
  end

  @doc """
  For some query periods, `now` or `relative_date` or both are irrelevant
  for resolving the date range. This dispatcher ensures that
  """
  def build_datetime_range(:realtime, timezone, _relative_date, now),
    do: build_realtime_range(timezone, now, 5)

  def build_datetime_range(:realtime_30m, timezone, _relative_date, now),
    do: build_realtime_range(timezone, now, 30)

  def build_datetime_range(:day, timezone, relative_date, now),
    do: build_day_range(timezone, relative_date, now)

  def build_datetime_range(:"24h", timezone, _relative_date, now),
    do: build_24h_range(timezone, now)

  def build_datetime_range(:month, timezone, relative_date, _now),
    do: build_month_range(timezone, relative_date)

  def build_datetime_range(:year, timezone, relative_date, _now),
    do: build_year_range(timezone, relative_date)

  def build_datetime_range({:last_n_days, n}, timezone, relative_date, _now),
    do: build_last_n_days_range(timezone, n, relative_date)

  def build_datetime_range({:last_n_months, n}, timezone, relative_date, _now),
    do: build_last_n_months_range(timezone, n, relative_date)

  def build_datetime_range({:date_range, from, to}, timezone, _relative_date, _now),
    do: build_date_range(timezone, from, to)

  def build_datetime_range({:datetime_range, from, to}, timezone, _relative_date, _now),
    do: build_range_from_datetimes(timezone, from, to)

  @doc """
  Resolves any site-dependent shape (currently only `:all`, which needs the
  site's stats start date) into a shape `build_datetime_range/4` can handle
  from a timezone alone. Other shapes pass through unchanged.
  """
  def resolve_input_date_range(:all, %Plausible.Site{} = site, relative_date) do
    start_date = Plausible.Sites.ensure_stats_start_date(site).stats_start_date || relative_date
    {:date_range, start_date, relative_date}
  end

  def resolve_input_date_range(input_date_range, _site, _relative_date),
    do: input_date_range

  @doc """
  Builds a realtime window of `duration_minutes` ending slightly after `now`.

  ## Examples

      iex> QueryPeriod.build_realtime_range("Etc/UTC", ~U[2026-05-05 12:30:00Z], 5)
      %DateTimeRange{first: ~U[2026-05-05 12:25:00Z], last: ~U[2026-05-05 12:30:05Z]}

      iex> QueryPeriod.build_realtime_range("Etc/UTC", ~U[2026-05-05 12:30:00Z], 30)
      %DateTimeRange{first: ~U[2026-05-05 12:00:00Z], last: ~U[2026-05-05 12:30:05Z]}
  """
  def build_realtime_range(timezone, now, duration_minutes) do
    first_datetime = DateTime.shift(now, minute: -duration_minutes)
    last_datetime = DateTime.shift(now, second: 5)

    DateTimeRange.new!(first_datetime, last_datetime)
    |> DateTimeRange.to_timezone(timezone)
  end

  @doc """
  Builds the range for a single calendar day. When `date` matches today in
  `timezone`, the range is truncated at `now`; otherwise it spans the full
  local day.

  ## Examples

      iex> QueryPeriod.build_day_range("Etc/UTC", ~D[2026-05-05], ~U[2026-05-05 12:30:00Z])
      %DateTimeRange{first: ~U[2026-05-05 00:00:00Z], last: ~U[2026-05-05 12:30:00Z]}

      iex> QueryPeriod.build_day_range("Etc/UTC", ~D[2026-05-04], ~U[2999-01-01 00:00:00Z])
      %DateTimeRange{first: ~U[2026-05-04 00:00:00Z], last: ~U[2026-05-04 23:59:59Z]}

      iex> QueryPeriod.build_day_range("Europe/Tallinn", ~D[2026-01-15], ~U[2999-01-01 00:00:00Z]) |> DateTimeRange.to_timezone("Etc/UTC")
      %DateTimeRange{first: ~U[2026-01-14 22:00:00Z], last: ~U[2026-01-15 21:59:59Z]}
  """
  def build_day_range(timezone, date, now) do
    if Date.compare(Times.to_date(now, timezone), date) == :eq do
      DateTimeRange.new!(date, now, timezone)
    else
      DateTimeRange.new!(date, date, timezone)
    end
  end

  @doc """
  Builds the 24-hour window ending at `now`.

  ## Examples

      iex> QueryPeriod.build_24h_range("Etc/UTC", ~U[2026-05-05 12:30:00Z])
      %DateTimeRange{first: ~U[2026-05-04 12:30:00Z], last: ~U[2026-05-05 12:30:00Z]}
  """
  def build_24h_range(timezone, now) do
    from = DateTime.shift(now, hour: -24)

    DateTimeRange.new!(from, now)
    |> DateTimeRange.to_timezone(timezone)
  end

  @doc """
  Builds the range spanning the calendar month containing `date`.

  ## Examples

      iex> QueryPeriod.build_month_range("Etc/UTC", ~D[2026-05-15])
      %DateTimeRange{first: ~U[2026-05-01 00:00:00Z], last: ~U[2026-05-31 23:59:59Z]}

      iex> QueryPeriod.build_month_range("Europe/Tallinn", ~D[2026-01-15]) |> DateTimeRange.to_timezone("Etc/UTC")
      %DateTimeRange{first: ~U[2025-12-31 22:00:00Z], last: ~U[2026-01-31 21:59:59Z]}
  """
  def build_month_range(timezone, date) do
    first = Date.beginning_of_month(date)
    last = Date.end_of_month(date)
    DateTimeRange.new!(first, last, timezone)
  end

  @doc """
  Builds the range spanning the calendar year containing `date`.

  ## Examples

      iex> QueryPeriod.build_year_range("Etc/UTC", ~D[2026-05-15])
      %DateTimeRange{first: ~U[2026-01-01 00:00:00Z], last: ~U[2026-12-31 23:59:59Z]}

      iex> QueryPeriod.build_year_range("Europe/Tallinn", ~D[2026-05-15]) |> DateTimeRange.to_timezone("Etc/UTC")
      %DateTimeRange{first: ~U[2025-12-31 22:00:00Z], last: ~U[2026-12-31 21:59:59Z]}
  """
  def build_year_range(timezone, date) do
    first = Times.beginning_of_year(date)
    last = Times.end_of_year(date)
    DateTimeRange.new!(first, last, timezone)
  end

  @doc """
  Builds a range spanning `n` full calendar days ending the day before
  `end_date`.

  ## Examples

      iex> QueryPeriod.build_last_n_days_range("Etc/UTC", 7, ~D[2026-05-08])
      %DateTimeRange{first: ~U[2026-05-01 00:00:00Z], last: ~U[2026-05-07 23:59:59Z]}

      iex> QueryPeriod.build_last_n_days_range("Europe/Tallinn", 7, ~D[2026-05-08]) |> DateTimeRange.to_timezone("Etc/UTC")
      %DateTimeRange{first: ~U[2026-04-30 21:00:00Z], last: ~U[2026-05-07 20:59:59Z]}
  """
  def build_last_n_days_range(timezone, n, end_date) do
    last = Date.add(end_date, -1)
    first = Date.add(end_date, -n)
    DateTimeRange.new!(first, last, timezone)
  end

  @doc """
  Builds a range spanning `n` full calendar months ending the month
  before `end_date`'s month.

  ## Examples

      iex> QueryPeriod.build_last_n_months_range("Etc/UTC", 3, ~D[2026-05-15])
      %DateTimeRange{first: ~U[2026-02-01 00:00:00Z], last: ~U[2026-04-30 23:59:59Z]}

      iex> QueryPeriod.build_last_n_months_range("Europe/Tallinn", 3, ~D[2026-05-15]) |> DateTimeRange.to_timezone("Etc/UTC")
      %DateTimeRange{first: ~U[2026-01-31 22:00:00Z], last: ~U[2026-04-30 20:59:59Z]}
  """
  def build_last_n_months_range(timezone, n, end_date) do
    last = end_date |> Date.shift(month: -1) |> Date.end_of_month()
    first = end_date |> Date.shift(month: -n) |> Date.beginning_of_month()
    DateTimeRange.new!(first, last, timezone)
  end

  @doc """
  Builds a range from explicit start/end calendar dates,
  from start of first day to end of last day in `timezone`.

  ## Examples

      iex> QueryPeriod.build_date_range("Etc/UTC", ~D[2026-05-01], ~D[2026-05-10])
      %DateTimeRange{first: ~U[2026-05-01 00:00:00Z], last: ~U[2026-05-10 23:59:59Z]}

      iex> QueryPeriod.build_date_range("Europe/Tallinn", ~D[2026-05-01], ~D[2026-05-10]) |> DateTimeRange.to_timezone("Etc/UTC")
      %DateTimeRange{first: ~U[2026-04-30 21:00:00Z], last: ~U[2026-05-10 20:59:59Z]}
  """
  def build_date_range(timezone, from, to) do
    DateTimeRange.new!(from, to, timezone)
  end

  @doc """
  Builds a range from explicit start/end datetimes, which may have any time zone,
  then shifts them to be in `timezone`.

  ## Examples

      iex> QueryPeriod.build_range_from_datetimes("Etc/UTC", ~U[2026-05-01 06:00:00Z], ~U[2026-05-01 18:00:00Z])
      %DateTimeRange{first: ~U[2026-05-01 06:00:00Z], last: ~U[2026-05-01 18:00:00Z]}
  """
  def build_range_from_datetimes(timezone, from, to) do
    DateTimeRange.new!(from, to)
    |> DateTimeRange.to_timezone(timezone)
  end
end
