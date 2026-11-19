defmodule PlausibleE2E.Dashboard.BehavioursSpecialGoalsTest do
  use PlausibleE2E.Case, async: true

  defp get_report(page), do: Page.get_by_test_id(page, "report-behaviours")

  test "special goals", %{page: page, request: request} do
    # `test.slow(headless === false)` isn't ported: pass --timeout when running headed
    report = get_report(page)
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/page1",
          timestamp: %{minutesAgo: 60}
        },
        %{
          user_id: 123,
          name: "Form: Submission",
          "meta.key": ["path"],
          "meta.value": ["/form-action/path"],
          timestamp: %{minutesAgo: 50}
        },
        %{
          user_id: 123,
          name: "404",
          "meta.key": ["path"],
          "meta.value": ["/wrong-path"],
          timestamp: %{minutesAgo: 45}
        },
        %{
          user_id: 123,
          name: "Outbound Link: Click",
          "meta.key": ["url"],
          "meta.value": ["https://example.com/link"],
          timestamp: %{minutesAgo: 40}
        },
        %{
          user_id: 123,
          name: "Cloaked Link: Click",
          "meta.key": ["url"],
          "meta.value": ["https://example.com/cloaked-link"],
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 123,
          name: "File Download",
          "meta.key": ["url"],
          "meta.value": ["https://example.com/file.zip"],
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 123,
          name: "WP Search Queries",
          "meta.key": ["search_query"],
          "meta.value": ["some query"],
          timestamp: %{minutesAgo: 25}
        },
        %{
          user_id: 123,
          name: "WP Form Completions",
          "meta.key": ["path"],
          "meta.value": ["/some/path"],
          timestamp: %{minutesAgo: 20}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/page1",
          timestamp: %{minutesAgo: 60}
        },
        %{
          user_id: 124,
          name: "Form: Submission",
          "meta.key": ["path"],
          "meta.value": ["/form-action/another-path"],
          timestamp: %{minutesAgo: 50}
        },
        %{
          user_id: 124,
          name: "404",
          "meta.key": ["path"],
          "meta.value": ["/another-wrong-path"],
          timestamp: %{minutesAgo: 45}
        },
        %{
          user_id: 124,
          name: "Outbound Link: Click",
          "meta.key": ["url"],
          "meta.value": ["https://example.com/another-link"],
          timestamp: %{minutesAgo: 40}
        },
        %{
          user_id: 124,
          name: "Cloaked Link: Click",
          "meta.key": ["url"],
          "meta.value": ["https://example.com/another-cloaked-link"],
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 124,
          name: "File Download",
          "meta.key": ["url"],
          "meta.value": ["https://example.com/another-file.zip"],
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 124,
          name: "WP Search Queries",
          "meta.key": ["search_query"],
          "meta.value": ["another query"],
          timestamp: %{minutesAgo: 25}
        },
        %{
          user_id: 124,
          name: "WP Form Completions",
          "meta.key": ["path"],
          "meta.value": ["/another/path"],
          timestamp: %{minutesAgo: 20}
        }
      ]
    )

    add_goal(request: request, domain: domain, params: %{event_name: "Cloaked Link: Click"})
    add_goal(request: request, domain: domain, params: %{event_name: "WP Search Queries"})
    add_goal(request: request, domain: domain, params: %{event_name: "WP Form Completions"})

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    goals_tab_button = tab_button(report, "Goals")

    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
    Expect.to_have_attribute!(goals_tab_button, "data-active", "true")

    expect_headers(report, ["Goal", "Uniques", "Total", "CR"])

    expect_metric_values(report, "Form: Submission", ["2", "2", "100%"])
    expect_metric_values(report, "404", ["2", "2", "100%"])
    expect_metric_values(report, "Outbound Link: Click", ["2", "2", "100%"])
    expect_metric_values(report, "Cloaked Link: Click", ["2", "2", "100%"])
    expect_metric_values(report, "File Download", ["2", "2", "100%"])
    expect_metric_values(report, "WP Search Queries", ["2", "2", "100%"])
    expect_metric_values(report, "WP Form Completions", ["2", "2", "100%"])

    Test.step "Form: Submission goal is treated as a special goal" do
      row_link(report, "Form: Submission") |> Locator.click!()

      report |> tab_button("Form actions") |> Expect.to_have_attribute!("data-active", "true")

      expect_headers(report, ["path", "Visitors", "Events", "CR"])

      expect_metric_values(report, "/form-action/path", ["1", "1", "50%"])
      expect_metric_values(report, "/form-action/another-path", ["1", "1", "50%"])
    end

    Test.step "Form: Submission special-goal modal" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "Form Actions")
      |> Expect.to_be_visible!()

      expect_headers(modal(page), ["path", ~r/Visitors/, ~r/Events/, ~r/CR/])

      expect_rows(modal(page), ["/form-action/another-path", "/form-action/path"])

      expect_metric_values(modal(page), "/form-action/path", ["1", "1", "50%"])

      page |> close_modal_button() |> Locator.click!()
    end

    Page.get_by_role(page, :button, name: "Remove filter: Goal is Form: Submission")
    |> Locator.click!()

    Locator.click!(goals_tab_button)

    Test.step "404 goal is treated as a special goal" do
      row_link(report, "404") |> Locator.click!()

      report |> tab_button("404 Pages") |> Expect.to_have_attribute!("data-active", "true")

      expect_headers(report, ["path", "Visitors", "Events", "CR"])

      expect_metric_values(report, "/wrong-path", ["1", "1", "50%"])
      expect_metric_values(report, "/another-wrong-path", ["1", "1", "50%"])
    end

    Test.step "404 special-goal modal" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "404 Pages")
      |> Expect.to_be_visible!()

      expect_headers(modal(page), ["path", ~r/Visitors/, ~r/Events/, ~r/CR/])

      expect_rows(modal(page), ["/another-wrong-path", "/wrong-path"])

      expect_metric_values(modal(page), "/wrong-path", ["1", "1", "50%"])

      page |> close_modal_button() |> Locator.click!()
    end

    Page.get_by_role(page, :button, name: "Remove filter: Goal is 404")
    |> Locator.click!()

    Locator.click!(goals_tab_button)

    Test.step "Outbound Link: Click goal is treated as a special goal" do
      row_link(report, "Outbound Link: Click") |> Locator.click!()

      report |> tab_button("Outbound Links") |> Expect.to_have_attribute!("data-active", "true")

      expect_headers(report, ["url", "Visitors", "Events", "CR"])

      expect_metric_values(report, "https://example.com/link", ["1", "1", "50%"])
      expect_metric_values(report, "https://example.com/another-link", ["1", "1", "50%"])
    end

    Test.step "Outbound Link: Click special-goal modal" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "Outbound Links")
      |> Expect.to_be_visible!()

      expect_headers(modal(page), ["url", ~r/Visitors/, ~r/Events/, ~r/CR/])

      expect_rows(modal(page), ["https://example.com/another-link", "https://example.com/link"])

      expect_metric_values(modal(page), "https://example.com/link", ["1", "1", "50%"])

      page |> close_modal_button() |> Locator.click!()
    end

    Page.get_by_role(page, :button, name: "Remove filter: Goal is Outbound Link: Click")
    |> Locator.click!()

    Locator.click!(goals_tab_button)

    Test.step "Cloaked Link: Click goal is treated as a special goal" do
      row_link(report, "Cloaked Link: Click") |> Locator.click!()

      report |> tab_button("Cloaked Links") |> Expect.to_have_attribute!("data-active", "true")

      expect_headers(report, ["url", "Visitors", "Events", "CR"])

      expect_metric_values(report, "https://example.com/cloaked-link", ["1", "1", "50%"])
      expect_metric_values(report, "https://example.com/another-cloaked-link", ["1", "1", "50%"])
    end

    Test.step "Cloaked Link: Click special-goal modal" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "Cloaked Links")
      |> Expect.to_be_visible!()

      expect_headers(modal(page), ["url", ~r/Visitors/, ~r/Events/, ~r/CR/])

      expect_rows(modal(page), [
        "https://example.com/another-cloaked-link",
        "https://example.com/cloaked-link"
      ])

      expect_metric_values(modal(page), "https://example.com/cloaked-link", ["1", "1", "50%"])

      page |> close_modal_button() |> Locator.click!()
    end

    Page.get_by_role(page, :button, name: "Remove filter: Goal is Cloaked Link: Click")
    |> Locator.click!()

    Locator.click!(goals_tab_button)

    Test.step "File Download goal is treated as a special goal" do
      row_link(report, "File Download") |> Locator.click!()

      report |> tab_button("File Downloads") |> Expect.to_have_attribute!("data-active", "true")

      expect_headers(report, ["url", "Visitors", "Events", "CR"])

      expect_metric_values(report, "https://example.com/file.zip", ["1", "1", "50%"])
      expect_metric_values(report, "https://example.com/another-file.zip", ["1", "1", "50%"])
    end

    Test.step "File Download special-goal modal" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "File Downloads")
      |> Expect.to_be_visible!()

      expect_headers(modal(page), ["url", ~r/Visitors/, ~r/Events/, ~r/CR/])

      expect_rows(modal(page), [
        "https://example.com/another-file.zip",
        "https://example.com/file.zip"
      ])

      expect_metric_values(modal(page), "https://example.com/file.zip", ["1", "1", "50%"])

      page |> close_modal_button() |> Locator.click!()
    end

    Page.get_by_role(page, :button, name: "Remove filter: Goal is File Download")
    |> Locator.click!()

    Locator.click!(goals_tab_button)

    Test.step "WP Search Queries goal is treated as a special goal" do
      row_link(report, "WP Search Queries") |> Locator.click!()

      report
      |> tab_button("WordPress Search Queries")
      |> Expect.to_have_attribute!("data-active", "true")

      expect_headers(report, ["search_query", "Visitors", "Events", "CR"])

      expect_metric_values(report, "some query", ["1", "1", "50%"])
      expect_metric_values(report, "another query", ["1", "1", "50%"])
    end

    Test.step "WP Search Queries special-goal modal" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "WordPress Search Queries")
      |> Expect.to_be_visible!()

      expect_headers(modal(page), ["search_query", ~r/Visitors/, ~r/Events/, ~r/CR/])

      expect_rows(modal(page), ["another query", "some query"])

      expect_metric_values(modal(page), "some query", ["1", "1", "50%"])

      page |> close_modal_button() |> Locator.click!()
    end

    Page.get_by_role(page, :button, name: "Remove filter: Goal is WP Search Queries")
    |> Locator.click!()

    Locator.click!(goals_tab_button)

    Test.step "WP Form Completions goal is treated as a special goal" do
      row_link(report, "WP Form Completions") |> Locator.click!()

      report
      |> tab_button("WordPress Form Completions")
      |> Expect.to_have_attribute!("data-active", "true")

      expect_headers(report, ["path", "Visitors", "Events", "CR"])

      expect_metric_values(report, "/some/path", ["1", "1", "50%"])
      expect_metric_values(report, "/another/path", ["1", "1", "50%"])
    end

    Test.step "WP Form Completions special-goal modal" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "WordPress Form Completions")
      |> Expect.to_be_visible!()

      expect_headers(modal(page), ["path", ~r/Visitors/, ~r/Events/, ~r/CR/])

      expect_rows(modal(page), ["/another/path", "/some/path"])

      expect_metric_values(modal(page), "/some/path", ["1", "1", "50%"])

      page |> close_modal_button() |> Locator.click!()
    end
  end
end
