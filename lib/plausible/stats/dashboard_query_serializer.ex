defmodule Plausible.Stats.DashboardQuerySerializer do
  @moduledoc """
  Takes a `%ParsedQueryParams{}` struct and turns it into a query
  string.
  """

  alias Plausible.Stats.ParsedQueryParams

  def serialize(%ParsedQueryParams{} = params) do
    encoded_query =
      params
      |> Map.to_list()
      |> Enum.flat_map(&get_serialized_fields/1)
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
      |> Enum.join("&")

    case encoded_query do
      "" -> ""
      encoded_query -> "?" <> encoded_query
    end
  end

  defp get_serialized_fields({_, nil}), do: []
  defp get_serialized_fields({_, []}), do: []

  defp get_serialized_fields({:input_date_range, {:date_range, from_date, to_date}}) do
    [
      {"period", "custom"},
      {"from", Date.to_iso8601(from_date)},
      {"to", Date.to_iso8601(to_date)}
    ]
  end

  defp get_serialized_fields({:input_date_range, input_date_range}) do
    period =
      case input_date_range do
        :realtime -> "realtime"
        :day -> "day"
        :month -> "month"
        :year -> "year"
        :all -> "all"
        {:last_n_days, 7} -> "7d"
        {:last_n_days, 28} -> "28d"
        {:last_n_days, 30} -> "30d"
        {:last_n_days, 91} -> "91d"
        {:last_n_months, 6} -> "6mo"
        {:last_n_months, 12} -> "12mo"
      end

    [{"period", period}]
  end

  defp get_serialized_fields({:relative_date, date}) do
    [{"date", Date.to_iso8601(date)}]
  end

  defp get_serialized_fields({:filters, [_ | _] = filters}) do
    filters
    |> Enum.map(fn [operator, dimension, clauses] ->
      clauses = Enum.map_join(clauses, ",", &uri_encode_permissive/1)
      dimension = String.split(dimension, ":", parts: 2) |> List.last()
      {"f", "#{operator},#{dimension},#{clauses}"}
    end)
  end

  defp get_serialized_fields(_) do
    []
  end

  # These charcters are not URL encoded to have more readable URLs.
  # Browsers seem to handle this just fine. `?f=is,page,/my/page/:some_param`
  # vs `?f=is,page,%2Fmy%2Fpage%2F%3Asome_param`
  @do_not_url_encode [":", "/"]

  defp uri_encode_permissive(input) do
    @do_not_url_encode
    |> Enum.map(fn char -> {char, URI.encode_www_form(char)} end)
    |> Enum.reduce(URI.encode_www_form(input), fn {char, char_encoded}, acc ->
      String.replace(acc, char_encoded, char)
    end)
  end
end
