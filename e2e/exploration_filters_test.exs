defmodule PlausibleE2E.Dashboard.ExplorationFiltersTest do
  use PlausibleE2E.Case, async: true

  defp get_report(page), do: Page.get_by_test_id(page, "report-behaviours")

  defp get_exploration_tab_button(report), do: tab_button(report, "Explore")

  test "change filters during a 3-step journey", %{page: page, request: request} do
    report = get_report(page)
    exploration_tab_button = get_exploration_tab_button(report)
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          user_id: 123,
          browser: "Firefox",
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 20}
        },
        %{
          user_id: 123,
          browser: "Firefox",
          name: "pageview",
          pathname: "/login",
          timestamp: %{minutesAgo: 19}
        },
        %{
          user_id: 123,
          browser: "Chrome",
          name: "pageview",
          pathname: "/dashboard",
          timestamp: %{minutesAgo: 18}
        },
        %{
          user_id: 124,
          browser: "Chrome",
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 20}
        },
        %{
          user_id: 124,
          browser: "Chrome",
          name: "pageview",
          pathname: "/login",
          timestamp: %{minutesAgo: 19}
        },
        %{
          user_id: 125,
          browser: "Safari",
          name: "pageview",
          pathname: "/other",
          timestamp: %{minutesAgo: 20}
        },
        %{
          user_id: 125,
          browser: "Safari",
          name: "pageview",
          pathname: "/journey",
          timestamp: %{minutesAgo: 19}
        }
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Locator.click!(exploration_tab_button)
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

    report
    |> Locator.get_by_test_id("exploration-title")
    |> Expect.to_have_text!("Explore user journeys")

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = Locator.get_by_test_id(report, "exploration-column-0")
    second_column = Locator.get_by_test_id(report, "exploration-column-1")
    third_column = Locator.get_by_test_id(report, "exploration-column-2")
    fourth_column = Locator.get_by_test_id(report, "exploration-column-3")

    first_column |> Locator.get_by_role(:button, name: "/home") |> Locator.click!()

    first_column
    |> Locator.get_by_role(:button, name: "/home")
    |> Expect.to_have_attribute!("data-exploration-step", "0")

    second_column |> Locator.get_by_role(:button, name: "/login") |> Locator.click!()

    second_column
    |> Locator.get_by_role(:button, name: "/login")
    |> Expect.to_have_attribute!("data-exploration-step", "1")

    third_column |> Locator.get_by_role(:button, name: "/dashboard") |> Locator.click!()

    third_column
    |> Locator.get_by_role(:button, name: "/dashboard")
    |> Expect.to_have_attribute!("data-exploration-step", "2")

    Expect.to_have_text!(fourth_column, ~r/No further steps found/)

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!([
      "/home",
      "/login",
      "/dashboard",
      "/journey",
      "/other"
    ])

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-value")
    |> Expect.to_have_text!(["2", "2", "1", "1", "1"])

    second_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(["/login"])

    second_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-value")
    |> Expect.to_have_text!(["2"])

    third_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(["No further action", "/dashboard"])

    third_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-value")
    |> Expect.to_have_text!(["1", "1"])

    Test.step "filtering with journey matches in all 3 steps" do
      page
      |> Page.get_by_test_id("report-devices")
      |> Locator.get_by_role(:link, name: "Firefox")
      |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/home"])

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["1"])

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/login"])

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["1"])

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/dashboard"])

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["1"])

      Expect.to_have_text!(fourth_column, ~r/No further steps found/)

      page
      |> Page.get_by_role(:button, name: "Remove filter: Browser is Firefox")
      |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/home"])

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["2"])

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/login"])

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["2"])

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/dashboard"])

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["1"])

      Expect.to_have_text!(fourth_column, ~r/No further steps found/)
    end

    Test.step "filtering with journey matches for 2 first steps" do
      page
      |> Page.get_by_test_id("report-devices")
      |> Locator.get_by_role(:link, name: "Chrome")
      |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/home"])

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["1"])

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/login"])

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["1"])

      Expect.to_have_text!(third_column, ~r/No further steps found/)
      Expect.to_be_hidden!(fourth_column)

      page
      |> Page.get_by_role(:button, name: "Remove filter: Browser is Chrome")
      |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/home"])

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["2"])

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/login"])

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["2"])

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["No further action", "/dashboard"])

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["1", "1"])

      third_column
      |> Locator.get_by_role(:button, name: "/dashboard")
      |> Expect.not_to_have_attribute!("data-exploration-step", "2")

      Expect.to_be_hidden!(fourth_column)
    end

    # select the 3rd step again
    third_column |> Locator.get_by_role(:button, name: "/dashboard") |> Locator.click!()

    third_column
    |> Locator.get_by_role(:button, name: "/dashboard")
    |> Expect.to_have_attribute!("data-exploration-step", "2")

    Test.step "filtering with journey with no matches for any of the steps" do
      page
      |> Page.get_by_test_id("report-devices")
      |> Locator.get_by_role(:link, name: "Safari")
      |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/journey", "/other"])

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["1", "1"])

      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)

      page
      |> Page.get_by_role(:button, name: "Remove filter: Browser is Safari")
      |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!([
        "/home",
        "/login",
        "/dashboard",
        "/journey",
        "/other"
      ])

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-value")
      |> Expect.to_have_text!(["2", "2", "1", "1", "1"])

      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)
    end
  end
end
