defmodule PlausibleE2E.Dashboard.BehavioursSpecialGoalsTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.BehavioursHelpers

  # {goal, meta key, minutes ago, value of user 123, value of user 124}
  @goals [
    {"Form: Submission", "path", 50, "/form-action/path", "/form-action/another-path"},
    {"404", "path", 45, "/wrong-path", "/another-wrong-path"},
    {"Outbound Link: Click", "url", 40, "https://example.com/link",
     "https://example.com/another-link"},
    {"Cloaked Link: Click", "url", 35, "https://example.com/cloaked-link",
     "https://example.com/another-cloaked-link"},
    {"File Download", "url", 30, "https://example.com/file.zip",
     "https://example.com/another-file.zip"},
    {"WP Search Queries", "search_query", 25, "some query", "another query"},
    {"WP Form Completions", "path", 20, "/some/path", "/another/path"}
  ]

  defp user_events(user_id, index) do
    [
      %{user_id: user_id, name: "pageview", pathname: "/page1", timestamp: %{minutesAgo: 60}}
      | for {name, key, minutes, v123, v124} <- @goals do
          %{
            user_id: user_id,
            name: name,
            "meta.key": [key],
            "meta.value": [elem({v123, v124}, index)],
            timestamp: %{minutesAgo: minutes}
          }
        end
    ]
  end

  test "special goals", %{page: page, request: request} do
    # `test.slow(headless === false)` isn't ported: pass --timeout when running headed
    report = report(page)
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: user_events(123, 0) ++ user_events(124, 1)
    )

    add_goal(request: request, domain: domain, params: %{event_name: "Cloaked Link: Click"})
    add_goal(request: request, domain: domain, params: %{event_name: "WP Search Queries"})
    add_goal(request: request, domain: domain, params: %{event_name: "WP Form Completions"})

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    goals_tab_button = tab_button(report, "Goals")

    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
    expect_active(goals_tab_button)

    expect_headers(report, ["Goal", "Uniques", "Total", "CR"])

    for {name, _, _, _, _} <- @goals do
      expect_metric_values(report, name, ["2", "2", "100%"])
    end

    specs = [
      %{
        goal: "Form: Submission",
        tab: "Form actions",
        modal: "Form Actions",
        key: "path",
        values: ["/form-action/path", "/form-action/another-path"],
        modal_rows: ["/form-action/another-path", "/form-action/path"]
      },
      %{
        goal: "404",
        tab: "404 Pages",
        modal: "404 Pages",
        key: "path",
        values: ["/wrong-path", "/another-wrong-path"],
        modal_rows: ["/another-wrong-path", "/wrong-path"]
      },
      %{
        goal: "Outbound Link: Click",
        tab: "Outbound Links",
        modal: "Outbound Links",
        key: "url",
        values: ["https://example.com/link", "https://example.com/another-link"],
        modal_rows: ["https://example.com/another-link", "https://example.com/link"]
      },
      %{
        goal: "Cloaked Link: Click",
        tab: "Cloaked Links",
        modal: "Cloaked Links",
        key: "url",
        values: ["https://example.com/cloaked-link", "https://example.com/another-cloaked-link"],
        modal_rows: [
          "https://example.com/another-cloaked-link",
          "https://example.com/cloaked-link"
        ]
      },
      %{
        goal: "File Download",
        tab: "File Downloads",
        modal: "File Downloads",
        key: "url",
        values: ["https://example.com/file.zip", "https://example.com/another-file.zip"],
        modal_rows: ["https://example.com/another-file.zip", "https://example.com/file.zip"]
      },
      %{
        goal: "WP Search Queries",
        tab: "WordPress Search Queries",
        modal: "WordPress Search Queries",
        key: "search_query",
        values: ["some query", "another query"],
        modal_rows: ["another query", "some query"]
      },
      %{
        goal: "WP Form Completions",
        tab: "WordPress Form Completions",
        modal: "WordPress Form Completions",
        key: "path",
        values: ["/some/path", "/another/path"],
        modal_rows: ["/another/path", "/some/path"]
      }
    ]

    last = length(specs) - 1

    for {spec, i} <- Enum.with_index(specs) do
      special_goal(page, report, spec)

      if i < last do
        Page.get_by_role(page, :button, name: "Remove filter: Goal is #{spec.goal}")
        |> Locator.click!()

        Locator.click!(goals_tab_button)
      end
    end
  end
end
