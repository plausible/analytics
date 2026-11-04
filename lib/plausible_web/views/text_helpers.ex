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
  Describes how long ago something was last used, e.g. a login session or a
  connected app.

  ### Examples:

      iex> PlausibleWeb.TextHelpers.humanize_last_used(nil)
      "Never"

      iex> PlausibleWeb.TextHelpers.humanize_last_used(~N[2026-01-01 09:00:00], ~N[2026-01-01 12:30:00])
      "3 hours ago"
  """
  @spec humanize_last_used(NaiveDateTime.t() | nil, NaiveDateTime.t()) :: String.t()
  def humanize_last_used(last_used_at, now \\ NaiveDateTime.utc_now(:second))

  def humanize_last_used(nil, _now), do: "Never"

  def humanize_last_used(last_used_at, now) do
    diff = NaiveDateTime.diff(now, last_used_at, :hour)
    diff_days = NaiveDateTime.diff(now, last_used_at, :day)

    cond do
      diff < 1 -> "Just recently"
      diff == 1 -> "1 hour ago"
      diff < 24 -> "#{diff} hours ago"
      diff < 2 * 24 -> "Yesterday"
      true -> "#{diff_days} days ago"
    end
  end

  def number_format(number) when is_integer(number) do
    Cldr.Number.to_string!(number)
  end

  def number_format(other), do: other
end
