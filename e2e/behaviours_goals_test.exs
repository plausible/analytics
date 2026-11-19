defmodule PlausibleE2E.Dashboard.BehavioursGoalsTest do
  use PlausibleE2E.Case, async: true

  @last_30min_pill "last 30min"

  defp get_report(page), do: Page.get_by_test_id(page, "report-behaviours")

  test "goals breakdown", %{page: page, request: request} do
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
          user_id: 124,
          name: "pageview",
          pathname: "/page1",
          timestamp: %{minutesAgo: 60}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/page1",
          timestamp: %{minutesAgo: 60}
        },
        %{
          user_id: 126,
          name: "pageview",
          pathname: "/page1",
          timestamp: %{minutesAgo: 60}
        },
        %{
          user_id: 123,
          name: "engagement",
          pathname: "/page1",
          scroll_depth: 80,
          timestamp: %{minutesAgo: 59}
        },
        %{
          user_id: 124,
          name: "engagement",
          pathname: "/page1",
          scroll_depth: 80,
          timestamp: %{minutesAgo: 59}
        },
        %{
          user_id: 125,
          name: "engagement",
          pathname: "/page1",
          scroll_depth: 80,
          timestamp: %{minutesAgo: 59}
        },
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
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(goals_tab_button, "data-active", "true")

      expect_headers(report, ["Goal", "Uniques", "Total", "CR", "Revenue", "Average"])

      expect_rows(report, ["Visit /page1", "Scroll 75% on /page1", "Add a site", "purchase"])
      expect_metric_values(report, "Visit /page1", ["4", "4", "100%", "-", "-"])
      expect_metric_values(report, "Scroll 75% on /page1", ["3", "-", "75%", "-", "-"])
      expect_metric_values(report, "Add a site", ["2", "2", "50%", "-", "-"])
      expect_metric_values(report, "purchase", ["1", "1", "25%", "€23.0", "€23.0"])
    end

    Test.step "goals modal" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "Goal conversions")
      |> Expect.to_be_visible!()

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

      page |> close_modal_button() |> Locator.click!()
    end

    Test.step "listing goals without revenue" do
      Page.goto!(page, "/" <> domain <> "?f=has_not_done,goal,purchase", wait_until: :commit)

      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(goals_tab_button, "data-active", "true")

      expect_headers(report, ["Goal", "Uniques", "Total", "CR"])

      expect_rows(report, ["Visit /page1", "Add a site", "Scroll 75% on /page1"])

      expect_metric_values(report, "Visit /page1", ["3", "3", "100%"])
      expect_metric_values(report, "Add a site", ["2", "2", "66.7%"])
      expect_metric_values(report, "Scroll 75% on /page1", ["2", "-", "66.7%"])
    end

    Test.step "goals modal without revenue" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "Goal conversions")
      |> Expect.to_be_visible!()

      expect_headers(modal(page), ["Goal", ~r/Uniques/, ~r/Total/, ~r/CR/])

      expect_rows(modal(page), ["Visit /page1", "Add a site", "Scroll 75% on /page1"])

      expect_metric_values(modal(page), "Visit /page1", ["3", "3", "100%"])

      page |> close_modal_button() |> Locator.click!()
    end

    Test.step "realtime goal index breakdown displays stats from last 30min" do
      Page.goto!(page, "/" <> domain <> "?period=realtime", wait_until: :commit)
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

      Expect.to_have_attribute!(goals_tab_button, "data-active", "true")
      Expect.to_be_visible!(Locator.get_by_text(report, @last_30min_pill))

      expect_headers(report, ["Goal", "Uniques", "Total", "CR"])

      expect_rows(report, ["Add a site"])
      expect_metric_values(report, "Add a site", ["2", "2", "100%"])
    end

    Test.step "realtime goals modal displays stats from last 30min" do
      report |> details_link() |> Locator.click!()

      page
      |> modal()
      |> Locator.get_by_role(:heading, name: "Goal conversions")
      |> Expect.to_be_visible!()

      expect_rows(modal(page), ["Add a site"])
      expect_metric_values(modal(page), "Add a site", ["2", "2", "100%"])

      page |> close_modal_button() |> Locator.click!()
    end
  end
end
