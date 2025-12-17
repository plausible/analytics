defmodule Plausible.Stats.DashboardQuerySerializer do
  @moduledoc """
  Takes a `%ParsedQueryParams{}` struct and turns it into a query
  string.
  """

  alias Plausible.Stats.{ParsedQueryParams, DashboardQueryParser, QueryInclude}

  def serialize(%ParsedQueryParams{} = params) do
    params
    |> Map.to_list()
    |> Enum.flat_map(&get_serialized_fields/1)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join("&", fn {key, value} -> "#{key}=#{value}" end)
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

  defp get_serialized_fields({:include, %QueryInclude{} = include}) do
    [:imports, :compare, :compare_match_day_of_week]
    |> Enum.flat_map(fn include_key ->
      get_serialized_fields_from_include(include_key, include)
    end)
  end

  defp get_serialized_fields(_) do
    []
  end

  defp get_serialized_fields_from_include(:imports, %QueryInclude{} = include) do
    if include.imports == DashboardQueryParser.default_include().imports do
      []
    else
      [{"with_imported", to_string(include.imports)}]
    end
  end

  defp get_serialized_fields_from_include(:compare, %QueryInclude{} = include) do
    case include.compare do
      nil ->
        []

      mode when mode in [:previous_period, :year_over_year] ->
        [{"comparison", to_string(mode)}]

      {:date_range, from_date, to_date} ->
        [
          {"comparison", "custom"},
          {"compare_from", Date.to_iso8601(from_date)},
          {"compare_to", Date.to_iso8601(to_date)}
        ]
    end
  end

  defp get_serialized_fields_from_include(:compare_match_day_of_week, include) do
    if include.compare_match_day_of_week ==
         DashboardQueryParser.default_include().compare_match_day_of_week do
      []
    else
      [{"match_day_of_week", to_string(include.compare_match_day_of_week)}]
    end
  end

  # These characters are not URL encoded to have more readable URLs.
  # Browsers seem to handle this just fine. `?f=is,page,/my/page/:some_param`
  # vs `?f=is,page,%2Fmy%2Fpage%2F%3Asome_param`
  @do_not_url_encode [":", "/"]
  @do_not_url_encode_map Enum.into(@do_not_url_encode, %{}, fn char ->
                           {URI.encode_www_form(char), char}
                         end)

  defp uri_encode_permissive(input) do
    input
    |> URI.encode_www_form()
    |> String.replace(Map.keys(@do_not_url_encode_map), &@do_not_url_encode_map[&1])
  end
end
