defmodule Plausible.Stats.DashboardQueryParser do
  @moduledoc """
  Parses a dashboard query string into `%ParsedQueryParams{}`. Note that
  `metrics` and `dimensions` do not exist at this step yet, and are expected
  to be filled in by each specific report.
  """

  alias Plausible.Stats.{ParsedQueryParams, QueryInclude}

  @default_include %QueryInclude{
    imports: true,
    # `include.imports_meta` can be true even when `include.imports`
    # is false. Even if we don't want to include imported data, we
    # might still want to know whether imported data can be toggled
    # on/off on the dashboard.
    imports_meta: true,
    time_labels: false,
    total_rows: false,
    trim_relative_date_range: true,
    compare: nil,
    compare_match_day_of_week: true,
    legacy_time_on_page_cutoff: nil
  }

  def default_include(), do: @default_include

  @default_pagination nil

  def default_pagination(), do: @default_pagination

  def parse(query_string, defaults \\ %{}) when is_binary(query_string) do
    query_string = String.trim_leading(query_string, "?")
    params_map = Map.merge(defaults, URI.decode_query(query_string))

    with {:ok, filters} <- parse_filters(query_string),
         {:ok, relative_date} <- parse_relative_date(params_map) do
      include =
        Map.merge(@default_include, %{
          imports: parse_include_imports(params_map),
          compare: parse_include_compare(params_map),
          compare_match_day_of_week: parse_include_compare_match_day_of_week(params_map)
        })

      {:ok,
       ParsedQueryParams.new!(%{
         metrics: [],
         dimensions: [],
         input_date_range: parse_input_date_range(params_map),
         relative_date: relative_date,
         filters: filters,
         include: include
       })}
    end
  end

  defp parse_input_date_range(%{"period" => "realtime"}), do: :realtime
  defp parse_input_date_range(%{"period" => "day"}), do: :day
  defp parse_input_date_range(%{"period" => "month"}), do: :month
  defp parse_input_date_range(%{"period" => "year"}), do: :year
  defp parse_input_date_range(%{"period" => "all"}), do: :all
  defp parse_input_date_range(%{"period" => "7d"}), do: {:last_n_days, 7}
  defp parse_input_date_range(%{"period" => "28d"}), do: {:last_n_days, 28}
  defp parse_input_date_range(%{"period" => "30d"}), do: {:last_n_days, 30}
  defp parse_input_date_range(%{"period" => "91d"}), do: {:last_n_days, 91}
  defp parse_input_date_range(%{"period" => "6mo"}), do: {:last_n_months, 6}
  defp parse_input_date_range(%{"period" => "12mo"}), do: {:last_n_months, 12}

  defp parse_input_date_range(%{"period" => "custom", "from" => from, "to" => to}) do
    from_date = Date.from_iso8601!(String.trim(from))
    to_date = Date.from_iso8601!(String.trim(to))
    {:date_range, from_date, to_date}
  end

  defp parse_input_date_range(_), do: nil

  defp parse_relative_date(%{"date" => date}) do
    case Date.from_iso8601(date) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp parse_relative_date(_), do: {:ok, nil}

  defp parse_include_imports(%{"with_imported" => "false"}), do: false
  defp parse_include_imports(_), do: true

  defp parse_include_compare(%{"comparison" => "previous_period"}), do: :previous_period
  defp parse_include_compare(%{"comparison" => "year_over_year"}), do: :year_over_year

  defp parse_include_compare(%{"comparison" => "custom"} = params) do
    from_date = Date.from_iso8601!(params["compare_from"])
    to_date = Date.from_iso8601!(params["compare_to"])
    {:date_range, from_date, to_date}
  end

  defp parse_include_compare(_options), do: nil

  defp parse_include_compare_match_day_of_week(%{"match_day_of_week" => "false"}), do: false
  defp parse_include_compare_match_day_of_week(_), do: true

  defp parse_filters(query_string) do
    with {:ok, filters} <- decode_filters(query_string) do
      Plausible.Stats.ApiQueryParser.parse_filters(filters)
    end
  end

  defp decode_filters(query_string) do
    query_string
    |> URI.query_decoder()
    |> Enum.filter(fn {key, _value} -> key == "f" end)
    |> Enum.reduce_while({:ok, []}, fn {_, filter_expression}, {:ok, acc} ->
      case decode_filter(filter_expression) do
        {:ok, filter} -> {:cont, {:ok, acc ++ [filter]}}
        {:error, _} -> {:halt, {:error, :invalid_filters}}
      end
    end)
  end

  defp decode_filter(filter_expression) do
    with [operator, dimension | clauses] <- String.split(filter_expression, ","),
         dimension = with_prefix(dimension),
         {:ok, clauses} <- decode_clauses(clauses, dimension) do
      {:ok, [operator, dimension, clauses]}
    else
      _ -> {:error, :invalid_filter}
    end
  end

  @event_prefix "event:"
  @visit_prefix "visit:"
  @no_prefix_dimensions ["segment"]
  defp with_prefix(dimension) do
    cond do
      dimension in @no_prefix_dimensions -> dimension
      event_dimension?(dimension) -> @event_prefix <> dimension
      true -> @visit_prefix <> dimension
    end
  end

  @dimensions_with_integer_clauses ["segment", "visit:city"]
  defp decode_clauses(clauses, dimension) when dimension in @dimensions_with_integer_clauses do
    Enum.reduce_while(clauses, {:ok, []}, fn clause, {:ok, acc} ->
      case Integer.parse(clause) do
        {int, ""} -> {:cont, {:ok, acc ++ [int]}}
        _ -> {:halt, {:error, :invalid_filter}}
      end
    end)
  end

  defp decode_clauses(clauses, _dimension) do
    {:ok, Enum.map(clauses, &URI.decode_www_form/1)}
  end

  @event_props_prefix "props:"
  @event_dimensions ["name", "page", "goal", "hostname"]
  defp event_dimension?(dimension) do
    dimension in @event_dimensions or String.starts_with?(dimension, @event_props_prefix)
  end
end
