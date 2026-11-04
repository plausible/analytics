defmodule PlausibleWeb.TextHelpers do
  @moduledoc false

  @spec pretty_join([String.t()]) :: String.t()

  @doc """
  Turns a list of strings into a string and replaces the last comma
  with the word "and".

  ### Examples:

      iex> ["one"] |> PlausibleWeb.TextHelpers.pretty_join()
      "one"

      iex> ["one", "two"] |> PlausibleWeb.TextHelpers.pretty_join()
      "one and two"

      iex> ["one", "two", "three"] |> PlausibleWeb.TextHelpers.pretty_join()
      "one, two and three"
  """
  def pretty_join([str]), do: str

  def pretty_join(list) do
    [last_string | rest] = Enum.reverse(list)

    rest_string =
      rest
      |> Enum.reverse()
      |> Enum.join(", ")

    "#{rest_string} and #{last_string}"
  end

  def pretty_list(list) do
    list
    |> Enum.map(&String.replace("#{&1}", "_", " "))
    |> pretty_join()
  end

  def format_date_range(date_range) do
    "#{format_date(date_range.first)} - #{format_date(date_range.last)}"
  end

  def format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end

  @doc """
  Describes how long ago something was last used, for a timestamp rewritten at
  most every 5 minutes while in use, like connected apps and Plugins API tokens.

  If the stored timestamp is at T1, the last actual use can be at T1 + 5 minutes,
  so past the first 10 minutes, the description is "about" the middle of that range.
  """
  @spec humanize_last_used_with_5_minute_precision(NaiveDateTime.t() | nil, NaiveDateTime.t()) ::
          String.t()
  def humanize_last_used_with_5_minute_precision(
        last_used_at,
        now \\ NaiveDateTime.utc_now(:second)
      )

  def humanize_last_used_with_5_minute_precision(nil, _now), do: "Never"

  def humanize_last_used_with_5_minute_precision(last_used_at, now) do
    minutes = NaiveDateTime.diff(now, last_used_at, :minute)
    hours = NaiveDateTime.diff(now, last_used_at, :hour)

    # The last actual use was between the stored timestamp and 5 minutes after
    # it, so its estimated age is the age of the middle of that range.
    estimated_age =
      NaiveDateTime.diff(
        now,
        NaiveDateTime.shift(last_used_at, minute: 2, second: 30),
        :millisecond
      )

    cond do
      minutes < 5 -> "Less than 5 minutes ago"
      minutes < 10 -> "Less than 10 minutes ago"
      minutes < 60 -> "About #{round(estimated_age / to_timeout(minute: 5)) * 5} minutes ago"
      hours < 24 -> about_hours_ago(round(estimated_age / to_timeout(hour: 1)))
      true -> days_ago(round(estimated_age / to_timeout(day: 1)))
    end
  end

  @doc """
  Describes how long ago something was last used, for a timestamp rewritten at
  most every hour while in use, like login and SSO sessions.

  If the stored timestamp is at T1, the last actual use can be at T1 + 1 hour,
  so past the first 2 hours, the description is "about" the middle of that range.
  """
  @spec humanize_last_used_with_hourly_precision(NaiveDateTime.t() | nil, NaiveDateTime.t()) ::
          String.t()
  def humanize_last_used_with_hourly_precision(
        last_used_at,
        now \\ NaiveDateTime.utc_now(:second)
      )

  def humanize_last_used_with_hourly_precision(nil, _now), do: "Never"

  def humanize_last_used_with_hourly_precision(last_used_at, now) do
    hours = NaiveDateTime.diff(now, last_used_at, :hour)

    # The last actual use was between the stored timestamp and an hour after it,
    # so its estimated age is the age of the middle of that range.
    estimated_age =
      NaiveDateTime.diff(now, NaiveDateTime.shift(last_used_at, minute: 30), :millisecond)

    cond do
      hours < 1 -> "Less than an hour ago"
      hours < 2 -> "Less than 2 hours ago"
      hours < 24 -> about_hours_ago(round(estimated_age / to_timeout(hour: 1)))
      true -> days_ago(round(estimated_age / to_timeout(day: 1)))
    end
  end

  defp about_hours_ago(1), do: "About 1 hour ago"
  defp about_hours_ago(hours), do: "About #{hours} hours ago"

  defp days_ago(1), do: "1 day ago"
  defp days_ago(days), do: "#{days} days ago"

  def number_format(number) when is_integer(number) do
    Cldr.Number.to_string!(number)
  end

  def number_format(other), do: other
end
