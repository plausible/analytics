defmodule PlausibleE2E.Dashboard.ExplorationBasicTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.ExplorationHelpers

  test "load user journey", %{page: page, request: request} do
    %{report: report} =
      open_exploration(page, request, [ev(123, "/page", %{daysAgo: 7})])

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = column(report, 0)
    second_column = column(report, 1)

    Expect.to_be_visible!(first_column)
    Expect.to_have_text!(labels(first_column), ["/page"])
    Expect.to_have_text!(values(first_column), ["1"])

    Expect.to_have_text!(second_column, ~r/1 step after/)
    Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)

    first_column |> button("/page") |> Locator.click!()
    expect_step(first_column, "/page", "0")
    Expect.to_have_text!(second_column, ~r/No further steps found/)
  end

  test "load user journey and switch to a period with no events without waiting for load", %{
    page: page,
    request: request
  } do
    %{report: report} =
      open_exploration(page, request, [ev(123, "/page", %{hoursAgo: 40})])

    # switch to 'Today'
    Keyboard.press!(Page.keyboard(page), "d")

    Expect.to_have_text!(report, ~r/No data yet/)
  end

  test "load user journey and switch to a period with no events", %{page: page, request: request} do
    %{report: report} =
      open_exploration(page, request, [ev(123, "/page", %{daysAgo: 7})])

    first_column = column(report, 0)

    Expect.to_be_visible!(first_column)
    Expect.to_have_text!(labels(first_column), ["/page"])

    # switch to 'Today'
    Keyboard.press!(Page.keyboard(page), "d")

    Expect.to_have_text!(report, ~r/No data yet/)
  end

  test "explore a 3-step funnel", %{page: page, request: request} do
    %{report: report} =
      open_exploration(page, request, [
        ev(123, "/home", mins(40)),
        ev(123, "/login", mins(35)),
        ev(123, "/dashboard", mins(30)),
        ev(124, "/home", mins(35)),
        ev(124, "/login", mins(30)),
        ev(125, "/home", mins(35)),
        ev(126, "/another", mins(40)),
        ev(126, "/journey", mins(35))
      ])

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = column(report, 0)
    second_column = column(report, 1)
    third_column = column(report, 2)

    first_column |> button("/home") |> Locator.click!()
    expect_step(first_column, "/home", "0")

    second_column |> button("/login") |> Locator.click!()
    expect_step(second_column, "/login", "1")

    third_column |> button("/dashboard") |> Locator.click!()
    expect_step(third_column, "/dashboard", "2")

    Expect.to_be_visible!(first_column)
    Expect.to_be_visible!(second_column)
    Expect.to_be_visible!(third_column)

    Expect.to_have_text!(labels(first_column), [
      "/home",
      "/login",
      "/another",
      "/dashboard",
      "/journey"
    ])

    expect_step(first_column, "/home", "0")
    Expect.to_have_text!(values(first_column), ["3", "2", "1", "1", "1"])

    Expect.to_have_text!(labels(second_column), ["/login", "No further action"])
    expect_step(second_column, "/login", "1")
    Expect.to_have_text!(values(second_column), ["2", "1"])

    Expect.to_have_text!(labels(third_column), ["No further action", "/dashboard"])
    expect_step(third_column, "/dashboard", "2")
    Expect.to_have_text!(values(third_column), ["1", "1"])

    Expect.to_have_text!(second_column, ~r/1 step after/)
    Expect.to_have_text!(third_column, ~r/2 steps after/)

    Test.step "Deselecting all resets the journey" do
      report |> Locator.get_by_test_id("exploration-deselect-all") |> Locator.click!()

      Expect.to_have_text!(second_column, ~r/Select a starting point to continue/)
      Expect.to_have_text!(third_column, ~r/Select an event to continue/)

      Expect.to_have_text!(labels(first_column), [
        "/home",
        "/login",
        "/another",
        "/dashboard",
        "/journey"
      ])

      expect_no_step(first_column, "/dashboard")
    end
  end

  test "explore journey hitting 20 step limit", %{page: page, request: request} do
    events = for i <- 0..20, do: ev(123, "/page#{i}", mins(100 - i))

    %{report: report} = open_exploration(page, request, events)

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = column(report, 0)
    last_column = column(report, 20)

    Expect.to_have_text!(labels(first_column), [
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
      col = column(report, i)
      col |> button("/page#{i}") |> Locator.click!()
      expect_step(col, "/page#{i}", "#{i}")
    end

    Expect.to_have_text!(last_column, ~r/You've reached the maximum journey depth/)
  end

  test "render various types of entries", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview", pathname: "/home"},
        %{name: "pageview", pathname: "/login"},
        %{name: "checkout"},
        %{name: "create_site"},
        %{name: "pageview", pathname: "/blog/first-post"},
        %{name: "pageview", pathname: "/blog/second-post"}
      ]
    )

    add_goal(
      request: request,
      domain: domain,
      params: %{event_name: "create_site", display_name: "Create a site"}
    )

    add_goal(request: request, domain: domain, params: %{page_path: "/login"})

    %{report: report} = open_exploration_for(page, domain)

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = column(report, 0)

    Expect.to_have_text!(labels(first_column), [
      "/blog",
      "checkout",
      "Create a site",
      "/blog/first-post",
      "/blog/second-post",
      "/home",
      "Visit /login"
    ])

    first_column |> row(0) |> Locator.locator("svg") |> Locator.hover!()

    Expect.to_have_text!(
      Page.get_by_role(page, :tooltip),
      ~r/Grouped pages: 2 pages with this prefix/
    )

    first_column |> row(2) |> Locator.locator("svg") |> Locator.hover!()
    Expect.to_have_text!(Page.get_by_role(page, :tooltip), ~r/Goal/)

    first_column |> row(6) |> Locator.locator("svg") |> Locator.hover!()
    Expect.to_have_text!(Page.get_by_role(page, :tooltip), ~r/Goal/)
  end

  test "load more suggestions", %{page: page, request: request} do
    pad = fn i -> i |> Integer.to_string() |> String.pad_leading(2, "0") end
    events1 = for i <- 0..24, do: %{name: "pageview", pathname: "/pageone#{pad.(i)}"}
    events2 = for i <- 0..24, do: %{name: "pageview", pathname: "/pagetwo#{pad.(i)}"}

    %{report: report} = open_exploration(page, request, events1 ++ events2)

    Expect.to_be_visible!(Locator.get_by_test_id(report, "exploration-direction-forward"))

    first_column = column(report, 0)
    column_row = fn i -> row(first_column, i) end

    first_page = for i <- 0..9, do: "/pageone#{pad.(i)}"
    second_page = for i <- 10..19, do: "/pageone#{pad.(i)}"

    Expect.to_have_text!(labels(first_column), first_page)

    Expect.to_have_text!(column_row.(10), ~r/Show 10 more/)
    Locator.click!(column_row.(10))

    Expect.to_have_text!(labels(first_column), first_page ++ second_page)

    Expect.to_have_text!(column_row.(20), ~r/Show 10 more/)

    Test.step "reset state when suggestions change" do
      first_column |> Locator.get_by_placeholder("Search") |> Locator.fill!("pagetwo")

      new_first_page = for i <- 0..9, do: "/pagetwo#{pad.(i)}"
      new_second_page = for i <- 10..19, do: "/pagetwo#{pad.(i)}"

      Expect.to_have_text!(labels(first_column), new_first_page)

      Expect.to_have_text!(column_row.(10), ~r/Show 10 more/)
      Locator.click!(column_row.(10))

      Expect.to_have_text!(labels(first_column), new_first_page ++ new_second_page)

      Expect.to_have_text!(column_row.(20), ~r/Show 5 more/)
    end
  end
end
