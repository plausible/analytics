defmodule PlausibleE2E.Dashboard.ExplorationSelectThreeStepsTest do
  use PlausibleE2E.Case, async: true

  defp get_report(page), do: Page.get_by_test_id(page, "report-behaviours")

  defp get_exploration_tab_button(report), do: tab_button(report, "Explore")

  test "select entries in a 3-step journey", %{page: page, request: request} do
    report = get_report(page)
    exploration_tab_button = get_exploration_tab_button(report)
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 40}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/login",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/dashboard",
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/login",
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/logout",
          timestamp: %{minutesAgo: 25}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/login",
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/dashboard",
          timestamp: %{minutesAgo: 25}
        },
        %{
          user_id: 126,
          name: "pageview",
          pathname: "/another-home",
          timestamp: %{minutesAgo: 40}
        },
        %{
          user_id: 126,
          name: "pageview",
          pathname: "/journey",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 126,
          name: "pageview",
          pathname: "/somewhere",
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 127,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 40}
        },
        %{
          user_id: 127,
          name: "pageview",
          pathname: "/blog",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 128,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 40}
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

    Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)

    first_column |> Locator.get_by_role(:button, name: "/home") |> Locator.click!()

    second_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(["/login", "No further action", "/blog"])

    Test.step "filter for \"No further action\" in the second step" do
      second_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("no further")

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["No further action"])
    end

    second_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("")

    second_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(["/login", "No further action", "/blog"])

    Test.step "select an entry in the 2nd step" do
      second_column |> Locator.get_by_role(:button, name: "/login") |> Locator.click!()

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/dashboard", "/logout"])

      second_column
      |> Locator.get_by_role(:button, name: "/login")
      |> Expect.to_have_attribute!("data-exploration-step", "1")
    end

    Test.step "select a different entry in the 2nd step" do
      second_column |> Locator.get_by_role(:button, name: "/blog") |> Locator.click!()
      Expect.to_have_text!(third_column, ~r/No further steps found/)

      second_column
      |> Locator.get_by_role(:button, name: "/blog")
      |> Expect.to_have_attribute!("data-exploration-step", "1")
    end

    Test.step "deselect an entry in the 2nd step" do
      second_column |> Locator.get_by_role(:button, name: "/blog") |> Locator.click!()
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)

      second_column
      |> Locator.get_by_role(:button, name: "/blog")
      |> Expect.not_to_have_attribute!("data-exploration-step", "1")

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/login", "No further action", "/blog"])
    end

    Test.step "select a different entry in the 1st step" do
      first_column |> Locator.get_by_role(:button, name: "/another-home") |> Locator.click!()

      first_column
      |> Locator.get_by_role(:button, name: "/another-home")
      |> Expect.to_have_attribute!("data-exploration-step", "0")

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/journey"])

      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
    end

    Test.step "select an entry in the 2nd step and 3rd step" do
      second_column |> Locator.get_by_role(:button, name: "/journey") |> Locator.click!()

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/somewhere"])

      third_column |> Locator.get_by_role(:button, name: "/somewhere") |> Locator.click!()
      Expect.to_have_text!(fourth_column, ~r/No further steps found/)
    end

    Test.step "deselect an entry at the 1st step" do
      first_column |> Locator.get_by_role(:button, name: "/another-home") |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!([
        "/home",
        "/login",
        "/dashboard",
        "/another-home",
        "/blog",
        "/journey",
        "/logout",
        "/somewhere"
      ])

      first_column
      |> Locator.get_by_role(:button, name: "/another-home")
      |> Expect.not_to_have_attribute!("data-exploration-step", "0")

      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)
    end
  end

  test "explore from end point", %{page: page, request: request} do
    report = get_report(page)
    exploration_tab_button = get_exploration_tab_button(report)
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 40}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/login",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/dashboard",
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/login",
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/logout",
          timestamp: %{minutesAgo: 25}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/login",
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/dashboard",
          timestamp: %{minutesAgo: 25}
        },
        %{
          user_id: 126,
          name: "pageview",
          pathname: "/another-home",
          timestamp: %{minutesAgo: 40}
        },
        %{
          user_id: 126,
          name: "pageview",
          pathname: "/journey",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 126,
          name: "pageview",
          pathname: "/somewhere",
          timestamp: %{minutesAgo: 30}
        },
        %{
          user_id: 127,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 40}
        },
        %{
          user_id: 127,
          name: "pageview",
          pathname: "/blog",
          timestamp: %{minutesAgo: 35}
        },
        %{
          user_id: 128,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 40}
        }
      ]
    )

    first_step_suggestions = [
      "/home",
      "/login",
      "/dashboard",
      "/another-home",
      "/blog",
      "/journey",
      "/logout",
      "/somewhere"
    ]

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Locator.click!(exploration_tab_button)
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

    report
    |> Locator.get_by_test_id("exploration-title")
    |> Expect.to_have_text!("Explore user journeys")

    first_column = Locator.get_by_test_id(report, "exploration-column-0")
    second_column = Locator.get_by_test_id(report, "exploration-column-1")
    third_column = Locator.get_by_test_id(report, "exploration-column-2")
    fourth_column = Locator.get_by_test_id(report, "exploration-column-3")

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(first_step_suggestions)

    Test.step "switch to end point, back to start point and to end point again" do
      report |> Locator.get_by_test_id("exploration-direction-forward") |> Locator.click!()
      report |> Locator.get_by_test_id("exploration-direction-backward") |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(first_step_suggestions)

      first_column
      |> Locator.get_by_role(:button, name: "/home")
      |> Expect.not_to_have_attribute!("data-exploration-step", "0")

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(first_step_suggestions)

      Expect.to_have_text!(second_column, ~r/1 step before/)
      Expect.to_have_text!(second_column, ~r/Select an end point to continue/)
      Expect.to_have_text!(third_column, ~r/2 steps before/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)

      report |> Locator.get_by_test_id("exploration-direction-backward") |> Locator.click!()
      report |> Locator.get_by_test_id("exploration-direction-forward") |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(first_step_suggestions)

      Expect.to_have_text!(second_column, ~r/1 step after/)
      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/2 steps after/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)
      Expect.to_be_hidden!(fourth_column)
    end

    Test.step "explore a 3-step journey from an end point" do
      report |> Locator.get_by_test_id("exploration-direction-forward") |> Locator.click!()
      report |> Locator.get_by_test_id("exploration-direction-backward") |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(first_step_suggestions)

      first_column |> Locator.get_by_role(:button, name: "/dashboard") |> Locator.click!()

      first_column
      |> Locator.get_by_role(:button, name: "/dashboard")
      |> Expect.to_have_attribute!("data-exploration-step", "0")

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/login"])

      Expect.to_have_text!(third_column, ~r/Select an event to continue/)

      second_column |> Locator.get_by_role(:button, name: "/login") |> Locator.click!()

      second_column
      |> Locator.get_by_role(:button, name: "/login")
      |> Expect.to_have_attribute!("data-exploration-step", "1")

      third_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/home"])

      third_column |> Locator.get_by_role(:button, name: "/home") |> Locator.click!()

      third_column
      |> Locator.get_by_role(:button, name: "/home")
      |> Expect.to_have_attribute!("data-exploration-step", "2")

      Expect.to_have_text!(fourth_column, ~r/No further steps found/)
    end

    Test.step "switch back to starting point" do
      report |> Locator.get_by_test_id("exploration-direction-backward") |> Locator.click!()
      report |> Locator.get_by_test_id("exploration-direction-forward") |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(first_step_suggestions)
    end
  end
end
