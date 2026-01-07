defmodule PlausibleWeb.Components.Dashboard.ReportListTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias PlausibleWeb.Components.Dashboard.ReportList
  alias Plausible.Stats.{ParsedQueryParams, QueryResult}
  import Plausible.DashboardTestUtils

  @report_list_selector ~s|[data-test-id="pages-report-list"]|
  @bar_indicator_selector ~s|[data-test-id="bar-indicator"]|

  setup do
    assigns = [
      site: build(:site),
      data_test_id: "pages-report-list",
      key_label: "Page",
      dimension: "event:page",
      params: %ParsedQueryParams{},
      external_link_fn: fn _ -> "" end
    ]

    {:ok, %{assigns: assigns}}
  end

  test "item bar width depends on visitors metric", %{assigns: assigns} do
    query_result =
      %QueryResult{
        results: [
          %{metrics: [100, 60.0], dimensions: ["/a"]},
          %{metrics: [70, 40.0], dimensions: ["/b"]},
          %{metrics: [30, 20.0], dimensions: ["/c"]}
        ],
        meta: Jason.OrderedObject.new(metric_labels: ["Conversions", "CR"]),
        query: Jason.OrderedObject.new(metrics: [:visitors, :conversion_rate])
      }

    assigns = Keyword.put(assigns, :query_result, query_result)

    html = render_component(&ReportList.report/1, assigns)

    report_list = find(html, @report_list_selector)

    [{1, "100.0%"}, {2, "70.0%"}, {3, "30.0%"}]
    |> Enum.each(fn {item, expected_width} ->
      bar =
        get_in_report_list(report_list, item, 0, text?: false)
        |> find(@bar_indicator_selector)

      assert text_of_attr(bar, "style") =~ "width: #{expected_width}"
    end)
  end
end
