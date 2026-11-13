defmodule Plausible.Stats.Query.DashboardParser do
  @moduledoc """
  Parses a dashboard query string into `%ParsedParams{}`. Note that
  `metrics` and `dimensions` do not exist at this step yet, and are expected
  to be filled in by each specific report.
  """

  alias Plausible.Stats.{Comparisons, Filters, Query, QueryError, QueryPeriod}

  alias Plausible.Stats.Query.{ParsedParams, ApiParser}

  def parse(params, opts \\ []) do
    with {:ok, input_date_range} <-
           QueryPeriod.parse_dashboard_input_date_range(params["date_range"]),
         {:ok, relative_date} <- QueryPeriod.parse_relative_date(params["relative_date"]),
         {:ok, dimensions} <- ApiParser.parse_dimensions(params["dimensions"]),
         {:ok, filters} <- Filters.Parser.parse(params["filters"]),
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
    with {:ok, compare} <- Comparisons.parse_compare(params["include"]["compare"]) do
      {:ok,
       %Query.Include{
         imports: params["include"]["imports"] == true,
         imports_meta: params["include"]["imports_meta"] == true,
         compare: compare,
         compare_match_day_of_week:
           Comparisons.parse_compare_match_day_of_week(
             params["include"]["compare_match_day_of_week"]
           ),
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
end
