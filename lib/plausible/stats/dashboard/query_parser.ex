defmodule Plausible.Stats.Dashboard.QueryParser do
  @moduledoc """
  Parses a dashboard query string into `%ParsedQueryParams{}`. Note that
  `metrics` and `dimensions` do not exist at this step yet, and are expected
  to be filled in by each specific report.
  """

  alias Plausible.Stats.{ParsedQueryParams, QueryInclude, ApiQueryParser}

  @default_include %QueryInclude{
    imports: true,
    # `include.imports_meta` can be true even when `include.imports`
    # is false. Even if we don't want to include imported data, we
    # might still want to know whether imported data can be toggled
    # on/off on the dashboard.
    imports_meta: false,
    time_labels: false,
    total_rows: false,
    trim_relative_date_range: true,
    compare: nil,
    compare_match_day_of_week: true,
    legacy_time_on_page_cutoff: nil,
    dashboard_metric_labels: true
  }

  def default_include(), do: @default_include

  @default_pagination nil

  def default_pagination(), do: @default_pagination

  @valid_period_shorthands %{
    "realtime" => :realtime,
    "realtime_30m" => :realtime_30m,
    "day" => :day,
    "month" => :month,
    "year" => :year,
    "all" => :all,
    "7d" => {:last_n_days, 7},
    "28d" => {:last_n_days, 28},
    "30d" => {:last_n_days, 30},
    "91d" => {:last_n_days, 91},
    "6mo" => {:last_n_months, 6},
    "12mo" => {:last_n_months, 12}
  }

  @valid_period_shorthand_keys Map.keys(@valid_period_shorthands)

  @valid_comparison_shorthands %{
    "previous_period" => :previous_period,
    "year_over_year" => :year_over_year
  }

  @valid_comparison_shorthand_keys Map.keys(@valid_comparison_shorthands)

  def parse(params) do
    with {:ok, filters} <- parse_filters(params),
         {:ok, relative_date} <- parse_relative_date(params),
         {:ok, metrics} <- parse_metrics(params) do
      input_date_range = parse_input_date_range(params)

      include =
        Map.merge(@default_include, %{
          imports: parse_include_imports(params),
          imports_meta: params["include_imports_meta"] == true,
          compare: parse_include_compare(params),
          compare_match_day_of_week: parse_match_day_of_week(params)
        })

      {:ok,
       ParsedQueryParams.new!(%{
         input_date_range: input_date_range,
         relative_date: relative_date,
         filters: filters,
         metrics: metrics,
         include: include
       })}
    end
  end

  defp parse_input_date_range(%{"period" => period})
       when period in @valid_period_shorthand_keys do
    @valid_period_shorthands[period]
  end

  defp parse_input_date_range(%{"period" => "custom", "from" => from, "to" => to}) do
    from_date = Date.from_iso8601!(String.trim(from))
    to_date = Date.from_iso8601!(String.trim(to))
    {:date_range, from_date, to_date}
  end

  defp parse_relative_date(%{"date" => date}) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp parse_relative_date(_), do: {:ok, nil}

  defp parse_metrics(%{"metrics" => [_ | _] = metrics}) do
    ApiQueryParser.parse_metrics(metrics)
  end

  defp parse_metrics(_), do: {:error, :invalid_metrics}

  defp parse_include_imports(%{"with_imported" => false}), do: false
  defp parse_include_imports(_), do: true

  defp parse_include_compare(%{"comparison" => "off"}), do: nil

  defp parse_include_compare(%{"comparison" => comparison})
       when comparison in @valid_comparison_shorthand_keys do
    @valid_comparison_shorthands[comparison]
  end

  defp parse_include_compare(%{"comparison" => "custom"} = params) do
    from_date = Date.from_iso8601!(params["compare_from"])
    to_date = Date.from_iso8601!(params["compare_to"])
    {:date_range, from_date, to_date}
  end

  defp parse_include_compare(_params), do: nil

  defp parse_match_day_of_week(%{"match_day_of_week" => false}), do: false
  defp parse_match_day_of_week(_params), do: true

  defp parse_filters(%{"filters" => filters}) when is_list(filters) do
    with {:ok, filters} <- decode_filters(filters) do
      Plausible.Stats.ApiQueryParser.parse_filters(filters)
    end
  end

  defp decode_filters(filters) do
    filters
    |> Enum.reduce_while({:ok, []}, fn filter_expression, {:ok, acc} ->
      case decode_filter(filter_expression) do
        {:ok, filter} -> {:cont, {:ok, acc ++ [filter]}}
        {:error, _} -> {:halt, {:error, :invalid_filters}}
      end
    end)
  end

  defp decode_filter(filter_expression) do
    with [operator, dimension, clauses] <- filter_expression,
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
