defmodule Plausible.DashboardTestUtils do
  @moduledoc false

  import Plausible.Test.Support.HTML

  def report_list_as_table(%LazyHTML{} = report_list, rows, columns) do
    for row_index <- 0..(rows - 1) do
      for column_index <- 0..(columns - 1) do
        get_in_report_list(report_list, row_index, column_index)
      end
    end
  end

  def get_in_report_list(%LazyHTML{} = report_list, row_index, column_index, opts \\ []) do
    selector = ~s|[data-test-id="report-list-#{row_index}-#{column_index}"]|

    cond do
      not element_exists?(report_list, selector) ->
        nil

      Keyword.get(opts, :text?, true) ->
        text_of_element(report_list, selector)

      true ->
        find(report_list, selector)
    end
  end
end
