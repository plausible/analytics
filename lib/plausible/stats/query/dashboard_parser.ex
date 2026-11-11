defmodule Plausible.Stats.Query.DashboardParser do
  @moduledoc """
  Parses a dashboard query string into `%ParsedParams{}`. Note that
  `metrics` and `dimensions` do not exist at this step yet, and are expected
  to be filled in by each specific report.
  """

  alias Plausible.Stats.{Query, QueryError}

  alias Plausible.Stats.Query.{ParsedParams, ApiParser}

  @valid_comparison_shorthands %{
    "previous_period" => :previous_period,
    "year_over_year" => :year_over_year
  }

  @valid_comparison_shorthand_keys Map.keys(@valid_comparison_shorthands)

  def parse(params, opts \\ []) do
    with {:ok, input_date_range} <- parse_input_date_range(params),
         {:ok, relative_date} <- parse_relative_date(params),
         {:ok, dimensions} <- ApiParser.parse_dimensions(params["dimensions"]),
         {:ok, filters} <- ApiParser.parse_filters(params["filters"]),
         {:ok, metrics} <- parse_metrics(params),
         {:ok, order_by} <- ApiParser.parse_order_by(params["order_by"]),
         {:ok, pagination} <- ApiParser.parse_pagination(params["pagination"]),
         {:ok, include} <- parse_include(params) do
      {:ok,
       ParsedParams.new!(%{
         input_date_range: input_date_range,
         relative_date: relative_date,
         dimensions: dimensions,
         filters: filters,
         metrics: metrics,
         order_by: order_by,
         pagination: pagination,
         include: include,
         skip_goal_existence_check: true,
         now: Keyword.get(opts, :now)
       })}
    end
  end

  defp parse_input_date_range(%{"date_range" => date_range}) do
    case date_range do
      "realtime" -> {:ok, :realtime}
      "realtime_30m" -> {:ok, :realtime_30m}
      date_range -> ApiParser.parse_input_date_range(date_range)
    end
  end

  defp parse_input_date_range(_) do
    {:error,
     %QueryError{code: :invalid_date_range, message: "Required 'date_range' parameter missing"}}
  end

  defp parse_relative_date(%{"relative_date" => date}) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} ->
        {:ok, date}

      _ ->
        {:error,
         %QueryError{code: :invalid_relative_date, message: "Failed to convert '#{date}' to date"}}
    end
  end

  defp parse_relative_date(_), do: {:ok, nil}

  defp parse_metrics(%{"metrics" => [_ | _] = metrics}) do
    ApiParser.parse_metrics(metrics)
  end

  defp parse_metrics(_),
    do:
      {:error,
       %QueryError{
         code: :invalid_metrics,
         message: "Expected at least one valid metric in 'metrics'"
       }}

  defp parse_include(params) do
    with {:ok, compare} <- parse_include_compare(params["include"]) do
      {:ok,
       %Query.Include{
         imports: params["include"]["imports"] == true,
         imports_meta: params["include"]["imports_meta"] == true,
         compare: compare,
         compare_match_day_of_week: params["include"]["compare_match_day_of_week"] == true,
         time_labels: params["include"]["time_labels"] == true,
         partial_time_labels: params["include"]["partial_time_labels"] == true,
         present_index: params["include"]["present_index"] == true,
         empty_metrics: params["include"]["empty_metrics"] == true,
         trim_relative_date_range: true,
         drop_unavailable_time_on_page: true,
         drop_unavailable_revenue_metrics: true
       }}
    end
  end

  defp parse_include_compare(%{"compare" => compare})
       when compare in @valid_comparison_shorthand_keys do
    {:ok, @valid_comparison_shorthands[compare]}
  end

  defp parse_include_compare(%{"compare" => [from, to] = compare})
       when is_binary(from) and is_binary(to) do
    case ApiParser.parse_date_strings(from, to) do
      {:ok, compare} ->
        {:ok, compare}

      {:error, _} ->
        {:error,
         %QueryError{
           code: :invalid_include,
           message: "Invalid include.compare '#{inspect(compare)}'"
         }}
    end
  end

  defp parse_include_compare(%{"compare" => compare}) when not is_nil(compare) do
    {:error,
     %QueryError{code: :invalid_include, message: "Invalid include.compare '#{inspect(compare)}'"}}
  end

  defp parse_include_compare(_) do
    {:ok, nil}
  end
end
