defmodule Plausible.Stats.Dashboard.QueryParser do
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

  def parse(query_string, site, user_prefs) when is_binary(query_string) do
    query_string = String.trim_leading(query_string, "?")
    params_map = URI.decode_query(query_string)

    with {:ok, filters} <- parse_filters(query_string),
         {:ok, relative_date} <- parse_relative_date(params_map) do
      input_date_range = parse_input_date_range(params_map, site, user_prefs)

      include =
        Map.merge(@default_include, %{
          imports: parse_include_imports(params_map),
          compare: parse_include_compare(params_map, user_prefs),
          compare_match_day_of_week: parse_match_day_of_week(params_map, user_prefs)
        })

      {:ok,
       ParsedQueryParams.new!(%{
         input_date_range: input_date_range,
         relative_date: relative_date,
         filters: filters,
         include: include
       })}
    end
  end

  defp parse_input_date_range(%{"period" => period}, _site, _user_prefs)
       when period in @valid_period_shorthand_keys do
    @valid_period_shorthands[period]
  end

  defp parse_input_date_range(
         %{"period" => "custom", "from" => from, "to" => to},
         _site,
         _user_prefs
       ) do
    from_date = Date.from_iso8601!(String.trim(from))
    to_date = Date.from_iso8601!(String.trim(to))
    {:date_range, from_date, to_date}
  end

  defp parse_input_date_range(_params, _site, %{"period" => period})
       when period in @valid_period_shorthand_keys do
    @valid_period_shorthands[period]
  end

  defp parse_input_date_range(_params, site, _user_prefs) do
    if recently_created?(site), do: :day, else: {:last_n_days, 28}
  end

  defp parse_relative_date(%{"date" => date}) do
    case Date.from_iso8601(date) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp parse_relative_date(_), do: {:ok, nil}

  defp parse_include_imports(%{"with_imported" => "false"}), do: false
  defp parse_include_imports(_), do: true

  defp parse_include_compare(%{"comparison" => "off"}, _user_prefs), do: nil

  defp parse_include_compare(%{"comparison" => comparison}, _user_prefs)
       when comparison in @valid_comparison_shorthand_keys do
    @valid_comparison_shorthands[comparison]
  end

  defp parse_include_compare(%{"comparison" => "custom"} = params, _user_prefs) do
    from_date = Date.from_iso8601!(params["compare_from"])
    to_date = Date.from_iso8601!(params["compare_to"])
    {:date_range, from_date, to_date}
  end

  defp parse_include_compare(_params, %{"comparison" => comparison})
       when comparison in @valid_comparison_shorthand_keys do
    @valid_comparison_shorthands[comparison]
  end

  defp parse_include_compare(_params, _user_prefs), do: nil

  defp parse_match_day_of_week(%{"match_day_of_week" => "false"}, _user_prefs), do: false
  defp parse_match_day_of_week(%{"match_day_of_week" => "true"}, _user_prefs), do: true
  defp parse_match_day_of_week(_params, %{"match_day_of_week" => "false"}), do: false
  defp parse_match_day_of_week(_params, _user_prefs), do: true

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

  defp recently_created?(site) do
    stats_start_date = NaiveDateTime.to_date(site.native_stats_start_at)
    Date.diff(stats_start_date, Date.utc_today()) >= -1
  end
end
