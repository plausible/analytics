defmodule PlausibleE2E.Dashboard.ExplorationSelectOneStepTest do
  use PlausibleE2E.Case, async: true

  defp get_report(page), do: Page.get_by_test_id(page, "report-behaviours")

  defp get_exploration_tab_button(report), do: tab_button(report, "Explore")

  test "select entries in a 1-step journey", %{page: page, request: request} do
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
          user_id: 125,
          name: "pageview",
          pathname: "/home",
          timestamp: %{minutesAgo: 35}
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

    Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!([
      "/home",
      "/login",
      "/another-home",
      "/dashboard",
      "/journey"
    ])

    first_column
    |> Locator.get_by_role(:button, name: "/home")
    |> Expect.not_to_have_attribute!("data-exploration-step", "0")

    Test.step "select an entry" do
      first_column |> Locator.get_by_role(:button, name: "/login") |> Locator.click!()

      first_column
      |> Locator.get_by_role(:button, name: "/login")
      |> Expect.to_have_attribute!("data-exploration-step", "0")

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["No further action", "/dashboard"])
    end

    Test.step "select a different entry" do
      first_column |> Locator.get_by_role(:button, name: "/another") |> Locator.click!()

      first_column
      |> Locator.get_by_role(:button, name: "/another-home")
      |> Expect.to_have_attribute!("data-exploration-step", "0")

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/journey"])
    end

    Test.step "select a different entry with no further steps" do
      first_column |> Locator.get_by_role(:button, name: "/dashboard") |> Locator.click!()

      first_column
      |> Locator.get_by_role(:button, name: "/dashboard")
      |> Expect.to_have_attribute!("data-exploration-step", "0")

      Expect.to_have_text!(second_column, ~r/No further steps found/)
    end

    Test.step "deselect an entry" do
      first_column |> Locator.get_by_role(:button, name: "/dashboard") |> Locator.click!()

      first_column
      |> Locator.get_by_role(:button, name: "/dashboard")
      |> Expect.not_to_have_attribute!("data-exploration-step", "0")

      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
    end

    Test.step "filter entries with match" do
      first_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("dash")

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/dashboard"])
    end

    Test.step "filter entries with no match" do
      first_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("nosuchthing")
      Expect.to_have_text!(first_column, ~r/No events found/)
    end

    Test.step "filter returning more than one entry" do
      first_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("home")

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/home", "/another-home"])
    end

    Test.step "select an entry with filtering applied" do
      first_column |> Locator.get_by_role(:button, name: "/home") |> Locator.click!()

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/login", "No further action"])

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/home", "/another-home"])

      first_column
      |> Locator.get_by_role(:button, name: "/home")
      |> Expect.to_have_attribute!("data-exploration-step", "0")
    end

    Test.step "select another entry with filtering still applied" do
      first_column |> Locator.get_by_role(:button, name: "/another-home") |> Locator.click!()

      second_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/journey"])

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(["/home", "/another-home"])

      first_column
      |> Locator.get_by_role(:button, name: "/another-home")
      |> Expect.to_have_attribute!("data-exploration-step", "0")
    end

    Test.step "deselect an entry with filtering still applied" do
      first_column |> Locator.get_by_role(:button, name: "/another-home") |> Locator.click!()

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!([
        "/home",
        "/login",
        "/another-home",
        "/dashboard",
        "/journey"
      ])

      first_column
      |> Locator.get_by_role(:button, name: "/another-home")
      |> Expect.not_to_have_attribute!("data-exploration-step", "0")

      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
    end
  end
end
