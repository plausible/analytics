defmodule PlausibleE2E.Dashboard.ExplorationBasicTest do
  use PlausibleE2E.Case, async: true

  defp get_report(page), do: Page.get_by_test_id(page, "report-behaviours")

  defp get_exploration_tab_button(report), do: tab_button(report, "Explore")

  test "load user journey", %{page: page, request: request} do
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
          pathname: "/page",
          timestamp: %{daysAgo: 7}
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

    Expect.to_be_visible!(first_column)

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(["/page"])

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-value")
    |> Expect.to_have_text!(["1"])

    Expect.to_have_text!(second_column, ~r/1 step after/)
    Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)

    first_column |> Locator.get_by_role(:button, name: "/page") |> Locator.click!()

    first_column
    |> Locator.get_by_role(:button, name: "/page")
    |> Expect.to_have_attribute!("data-exploration-step", "0")

    Expect.to_have_text!(second_column, ~r/No further steps found/)
  end

  test "load user journey and switch to a period with no events without waiting for load", %{
    page: page,
    request: request
  } do
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
          pathname: "/page",
          timestamp: %{hoursAgo: 40}
        }
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Locator.click!(exploration_tab_button)
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

    report
    |> Locator.get_by_test_id("exploration-title")
    |> Expect.to_have_text!("Explore user journeys")

    # switch to 'Today'
    Keyboard.press!(Page.keyboard(page), "d")

    Expect.to_have_text!(report, ~r/No data yet/)
  end

  test "load user journey and switch to a period with no events", %{page: page, request: request} do
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
          pathname: "/page",
          timestamp: %{daysAgo: 7}
        }
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Locator.click!(exploration_tab_button)
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

    report
    |> Locator.get_by_test_id("exploration-title")
    |> Expect.to_have_text!("Explore user journeys")

    first_column = Locator.get_by_test_id(report, "exploration-column-0")

    Expect.to_be_visible!(first_column)

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(["/page"])

    # switch to 'Today'
    Keyboard.press!(Page.keyboard(page), "d")

    Expect.to_have_text!(report, ~r/No data yet/)
  end

  test "explore a 3-step funnel", %{page: page, request: request} do
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
          pathname: "/another",
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
    third_column = Locator.get_by_test_id(report, "exploration-column-2")

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

    Expect.to_be_visible!(first_column)
    Expect.to_be_visible!(second_column)
    Expect.to_be_visible!(third_column)

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!([
      "/home",
      "/login",
      "/another",
      "/dashboard",
      "/journey"
    ])

    first_column
    |> Locator.get_by_role(:button, name: "/home")
    |> Expect.to_have_attribute!("data-exploration-step", "0")

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-value")
    |> Expect.to_have_text!(["3", "2", "1", "1", "1"])

    second_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(["/login", "No further action"])

    second_column
    |> Locator.get_by_role(:button, name: "/login")
    |> Expect.to_have_attribute!("data-exploration-step", "1")

    second_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-value")
    |> Expect.to_have_text!(["2", "1"])

    third_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(["No further action", "/dashboard"])

    third_column
    |> Locator.get_by_role(:button, name: "/dashboard")
    |> Expect.to_have_attribute!("data-exploration-step", "2")

    third_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-value")
    |> Expect.to_have_text!(["1", "1"])

    Expect.to_have_text!(second_column, ~r/1 step after/)
    Expect.to_have_text!(third_column, ~r/2 steps after/)

    Test.step "Deselecting all resets the journey" do
      report |> Locator.get_by_test_id("exploration-deselect-all") |> Locator.click!()

      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!([
        "/home",
        "/login",
        "/another",
        "/dashboard",
        "/journey"
      ])

      first_column
      |> Locator.get_by_role(:button, name: "/dashboard")
      |> Expect.not_to_have_attribute!("data-exploration-step")
    end
  end

  test "explore journey hitting 20 step limit", %{page: page, request: request} do
    report = get_report(page)
    exploration_tab_button = get_exploration_tab_button(report)
    %{domain: domain} = setup_site(page: page, request: request)

    events =
      for i <- 0..20 do
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/page#{i}",
          timestamp: %{minutesAgo: 100 - i}
        }
      end

    populate_stats(request: request, domain: domain, events: events)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Locator.click!(exploration_tab_button)
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

    report
    |> Locator.get_by_test_id("exploration-title")
    |> Expect.to_have_text!("Explore user journeys")

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = Locator.get_by_test_id(report, "exploration-column-0")
    last_column = Locator.get_by_test_id(report, "exploration-column-20")

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!([
      "/page0",
      "/page1",
      "/page10",
      "/page11",
      "/page12",
      "/page13",
      "/page14",
      "/page15",
      "/page16",
      "/page17"
    ])

    for i <- 0..19 do
      column = Locator.get_by_test_id(report, "exploration-column-#{i}")

      column |> Locator.get_by_role(:button, name: "/page#{i}") |> Locator.click!()

      column
      |> Locator.get_by_role(:button, name: "/page#{i}")
      |> Expect.to_have_attribute!("data-exploration-step", "#{i}")
    end

    Expect.to_have_text!(last_column, ~r/You've reached the maximum journey depth/)
  end

  test "render various types of entries", %{page: page, request: request} do
    report = get_report(page)
    exploration_tab_button = get_exploration_tab_button(report)
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          name: "pageview",
          pathname: "/home"
        },
        %{
          name: "pageview",
          pathname: "/login"
        },
        %{
          name: "checkout"
        },
        %{
          name: "create_site"
        },
        %{
          name: "pageview",
          pathname: "/blog/first-post"
        },
        %{
          name: "pageview",
          pathname: "/blog/second-post"
        }
      ]
    )

    add_goal(
      request: request,
      domain: domain,
      params: %{event_name: "create_site", display_name: "Create a site"}
    )

    add_goal(request: request, domain: domain, params: %{page_path: "/login"})

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Locator.click!(exploration_tab_button)
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

    report
    |> Locator.get_by_test_id("exploration-title")
    |> Expect.to_have_text!("Explore user journeys")

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = Locator.get_by_test_id(report, "exploration-column-0")

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!([
      "/blog",
      "checkout",
      "Create a site",
      "/blog/first-post",
      "/blog/second-post",
      "/home",
      "Visit /login"
    ])

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.nth(0)
    |> Locator.locator("svg")
    |> Locator.hover!()

    Expect.to_have_text!(
      Page.get_by_role(page, :tooltip),
      ~r/Grouped pages: 2 pages with this prefix/
    )

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.nth(2)
    |> Locator.locator("svg")
    |> Locator.hover!()

    Expect.to_have_text!(Page.get_by_role(page, :tooltip), ~r/Goal/)

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.nth(6)
    |> Locator.locator("svg")
    |> Locator.hover!()

    Expect.to_have_text!(Page.get_by_role(page, :tooltip), ~r/Goal/)
  end

  test "load more suggestions", %{page: page, request: request} do
    report = get_report(page)
    exploration_tab_button = get_exploration_tab_button(report)
    %{domain: domain} = setup_site(page: page, request: request)

    events1 =
      for i <- 0..24 do
        %{
          name: "pageview",
          pathname: "/pageone#{String.pad_leading(Integer.to_string(i), 2, "0")}"
        }
      end

    events2 =
      for i <- 0..24 do
        %{
          name: "pageview",
          pathname: "/pagetwo#{String.pad_leading(Integer.to_string(i), 2, "0")}"
        }
      end

    populate_stats(
      request: request,
      domain: domain,
      events: events1 ++ events2
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Locator.click!(exploration_tab_button)
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

    report
    |> Locator.get_by_test_id("exploration-title")
    |> Expect.to_have_text!("Explore user journeys")

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = Locator.get_by_test_id(report, "exploration-column-0")

    column_row = fn i ->
      first_column |> Locator.get_by_test_id("exploration-row") |> Locator.nth(i)
    end

    first_page = [
      "/pageone00",
      "/pageone01",
      "/pageone02",
      "/pageone03",
      "/pageone04",
      "/pageone05",
      "/pageone06",
      "/pageone07",
      "/pageone08",
      "/pageone09"
    ]

    second_page = [
      "/pageone10",
      "/pageone11",
      "/pageone12",
      "/pageone13",
      "/pageone14",
      "/pageone15",
      "/pageone16",
      "/pageone17",
      "/pageone18",
      "/pageone19"
    ]

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(first_page)

    Expect.to_have_text!(column_row.(10), ~r/Show 10 more/)
    Locator.click!(column_row.(10))

    first_column
    |> Locator.get_by_test_id("exploration-row")
    |> Locator.get_by_test_id("metric-label")
    |> Expect.to_have_text!(first_page ++ second_page)

    Expect.to_have_text!(column_row.(20), ~r/Show 10 more/)

    Test.step "reset state when suggestions change" do
      first_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("pagetwo")

      new_first_page = [
        "/pagetwo00",
        "/pagetwo01",
        "/pagetwo02",
        "/pagetwo03",
        "/pagetwo04",
        "/pagetwo05",
        "/pagetwo06",
        "/pagetwo07",
        "/pagetwo08",
        "/pagetwo09"
      ]

      new_second_page = [
        "/pagetwo10",
        "/pagetwo11",
        "/pagetwo12",
        "/pagetwo13",
        "/pagetwo14",
        "/pagetwo15",
        "/pagetwo16",
        "/pagetwo17",
        "/pagetwo18",
        "/pagetwo19"
      ]

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(new_first_page)

      Expect.to_have_text!(column_row.(10), ~r/Show 10 more/)
      Locator.click!(column_row.(10))

      first_column
      |> Locator.get_by_test_id("exploration-row")
      |> Locator.get_by_test_id("metric-label")
      |> Expect.to_have_text!(new_first_page ++ new_second_page)

      Expect.to_have_text!(column_row.(20), ~r/Show 5 more/)
    end
  end
end
