defmodule PlausibleE2E.Dashboard.BehavioursGoalsTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.BehavioursHelpers

  test "goals breakdown", %{page: page, request: request} do
    report = report(page)
    %{domain: domain} = setup_site(page: page, request: request)

    pageview = fn user_id ->
      %{user_id: user_id, name: "pageview", pathname: "/page1", timestamp: %{minutesAgo: 60}}
    end

    engagement = fn user_id ->
      %{
        user_id: user_id,
        name: "engagement",
        pathname: "/page1",
        scroll_depth: 80,
        timestamp: %{minutesAgo: 59}
      }
    end

    populate_stats(
      request: request,
      domain: domain,
      events: [
        pageview.(123),
        pageview.(124),
        pageview.(125),
        pageview.(126),
        engagement.(123),
        engagement.(124),
        engagement.(125),
        %{
          user_id: 123,
          name: "purchase",
          pathname: "/buy",
          revenue_reporting_amount: "23",
          revenue_reporting_currency: "EUR",
          timestamp: %{minutesAgo: 59}
        },
        %{user_id: 124, name: "add_site", timestamp: %{minutesAgo: 15}},
        %{user_id: 125, name: "add_site", timestamp: %{minutesAgo: 2}}
      ]
    )

    add_custom_goal(page: page, domain: domain, name: "add_site", display_name: "Add a site")
    add_custom_goal(page: page, domain: domain, name: "purchase", currency: "EUR")
    add_pageview_goal(page: page, domain: domain, pathname: "/page1")

    add_scroll_depth_goal(
      page: page,
      domain: domain,
      pathname: "/page1",
      scroll_percentage: 75
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    goals_tab_button = tab_button(report, "Goals")

    Test.step "listing all goals" do
      scroll_to_end(report)
      expect_active(goals_tab_button)

      expect_headers(report, ["Goal", "Uniques", "Total", "CR", "Revenue", "Average"])

      expect_rows(report, ["Visit /page1", "Scroll 75% on /page1", "Add a site", "purchase"])
      expect_metric_values(report, "Visit /page1", ["4", "4", "100%", "-", "-"])
      expect_metric_values(report, "Scroll 75% on /page1", ["3", "-", "75%", "-", "-"])
      expect_metric_values(report, "Add a site", ["2", "2", "50%", "-", "-"])
      expect_metric_values(report, "purchase", ["1", "1", "25%", "€23.0", "€23.0"])
    end

    Test.step "goals modal" do
      report |> details_link() |> Locator.click!()

      expect_modal_heading(page, "Goal conversions")

      expect_headers(modal(page), [
        "Goal",
        ~r/Uniques/,
        ~r/Total/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), ["Visit /page1", "Scroll 75% on /page1", "Add a site", "purchase"])

      expect_metric_values(modal(page), "Visit /page1", ["4", "4", "100%", "-", "-"])

      close_modal(page)
    end

    Test.step "listing goals without revenue" do
      Page.goto!(page, "/" <> domain <> "?f=has_not_done,goal,purchase", wait_until: :commit)

      scroll_to_end(report)
      expect_active(goals_tab_button)

      expect_headers(report, ["Goal", "Uniques", "Total", "CR"])

      expect_rows(report, ["Visit /page1", "Add a site", "Scroll 75% on /page1"])

      expect_metric_values(report, "Visit /page1", ["3", "3", "100%"])
      expect_metric_values(report, "Add a site", ["2", "2", "66.7%"])
      expect_metric_values(report, "Scroll 75% on /page1", ["2", "-", "66.7%"])
    end

    Test.step "goals modal without revenue" do
      report |> details_link() |> Locator.click!()

      expect_modal_heading(page, "Goal conversions")

      expect_headers(modal(page), ["Goal", ~r/Uniques/, ~r/Total/, ~r/CR/])

      expect_rows(modal(page), ["Visit /page1", "Add a site", "Scroll 75% on /page1"])

      expect_metric_values(modal(page), "Visit /page1", ["3", "3", "100%"])

      close_modal(page)
    end

    Test.step "realtime goal index breakdown displays stats from last 30min" do
      Page.goto!(page, "/" <> domain <> "?period=realtime", wait_until: :commit)
      scroll_to_end(report)

      expect_active(goals_tab_button)
      Expect.to_be_visible!(Locator.get_by_text(report, last_30min_pill()))

      expect_headers(report, ["Goal", "Uniques", "Total", "CR"])

      expect_rows(report, ["Add a site"])
      expect_metric_values(report, "Add a site", ["2", "2", "100%"])
    end

    Test.step "realtime goals modal displays stats from last 30min" do
      report |> details_link() |> Locator.click!()

      expect_modal_heading(page, "Goal conversions")

      expect_rows(modal(page), ["Add a site"])
      expect_metric_values(modal(page), "Add a site", ["2", "2", "100%"])

      close_modal(page)
    end
  end
end
