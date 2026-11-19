defmodule PlausibleE2E.Dashboard.BreakdownsPagesTest do
  use PlausibleE2E.Case, async: true

  test "pages breakdown", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{user_id: 123, name: "pageview", pathname: "/page1"},
        %{user_id: 123, name: "pageview", pathname: "/page2"},
        %{user_id: 123, name: "pageview", pathname: "/page3"},
        %{user_id: 124, name: "pageview", pathname: "/page1"},
        %{user_id: 124, name: "pageview", pathname: "/page2"},
        %{name: "pageview", pathname: "/page1"},
        %{name: "pageview", pathname: "/other"}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    report = Page.get_by_test_id(page, "report-pages")

    Test.step "top pages tab" do
      pages_tab_button = tab_button(report, "Top pages")
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(pages_tab_button, "data-active", "true")

      expect_headers(report, ["Page", "Visitors"])

      expect_rows(report, ["/page1", "/page2", "/other", "/page3"])

      expect_metric_values(report, "/page1", ["3", "75%"])
      expect_metric_values(report, "/page2", ["2", "50%"])
      expect_metric_values(report, "/other", ["1", "25%"])
      expect_metric_values(report, "/page3", ["1", "25%"])
    end

    Test.step "entry pages tab" do
      entry_pages_tab_button = tab_button(report, "Entry pages")
      Locator.click!(entry_pages_tab_button)
      Expect.to_have_attribute!(entry_pages_tab_button, "data-active", "true")

      expect_headers(report, ["Entry page", "Unique entrances"])

      expect_rows(report, ["/page1", "/other"])

      expect_metric_values(report, "/page1", ["3", "75%"])
      expect_metric_values(report, "/other", ["1", "25%"])
    end

    Test.step "Entry pages modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Entry pages"))

      expect_headers(modal(page), [
        "Entry page",
        ~r/Unique entrances/,
        ~r/Total entrances/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["/page1", "/other"])

      expect_metric_values(modal(page), "/page1", ["3", "3", "33%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "exit pages tab" do
      exit_pages_tab_button = tab_button(report, "Exit pages")
      Locator.click!(exit_pages_tab_button)
      Expect.to_have_attribute!(exit_pages_tab_button, "data-active", "true")

      expect_headers(report, ["Exit page", "Unique exits"])

      expect_rows(report, ["/other", "/page1", "/page2", "/page3"])

      expect_metric_values(report, "/other", ["1", "25%"])
      expect_metric_values(report, "/page1", ["1", "25%"])
      expect_metric_values(report, "/page2", ["1", "25%"])
      expect_metric_values(report, "/page3", ["1", "25%"])
    end

    Test.step "Exit pages modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Exit pages"))

      expect_headers(modal(page), ["Exit page", ~r/Unique exits/, ~r/Total exits/, ~r/Exit rate/])

      expect_rows(modal(page), ["/other", "/page1", "/page2", "/page3"])

      expect_metric_values(modal(page), "/other", ["1", "1", "100%"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "exit pages modal with an event filter applied" do
      Page.goto!(page, "/" <> domain <> "?f=is,page,/page1", wait_until: :commit)
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Exit pages"))

      expect_headers(modal(page), ["Exit page", ~r/Unique exits/, ~r/Total exits/])

      expect_rows(modal(page), ["/page1", "/page2", "/page3"])

      expect_metric_values(modal(page), "/page1", ["1", "1"])
      expect_metric_values(modal(page), "/page2", ["1", "1"])
      expect_metric_values(modal(page), "/page3", ["1", "1"])

      close_modal_button(page) |> Locator.click!()
    end
  end
end

defmodule PlausibleE2E.Dashboard.BreakdownsPagesModalTest do
  use PlausibleE2E.Case, async: true

  test "pages breakdown modal", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    pages_count = 110

    # We generate <pages_count> unique page entries, each with a different number of visits
    page_events =
      for idx <- 0..(pages_count - 1),
          _ <- 1..(idx + 1),
          do: %{name: "pageview", pathname: "/page#{idx + 1}/foo"}

    populate_stats(request: request, domain: domain, events: page_events)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    report = Page.get_by_test_id(page, "report-pages")

    pages_tab_button = tab_button(report, "Top pages")
    report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
    Expect.to_have_attribute!(pages_tab_button, "data-active", "true")

    details_link(report) |> Locator.click!()

    Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Top pages"))

    expect_headers(modal(page), [
      "Page",
      ~r/Visitors/,
      ~r/Pageviews/,
      ~r/Bounce rate/,
      ~r/Time on page/,
      ~r/Scroll depth/
    ])

    Test.step "displays 100 entries on a single page" do
      page_rows = for idx <- 0..99, do: "/page#{pages_count - idx}/foo"

      expect_rows(modal(page), page_rows)

      expect_metric_values(modal(page), "/page110/foo", ["110", "110", "100%", "-", "-"])

      expect_metric_values(modal(page), "/page11/foo", ["11", "11", "100%", "-", "-"])
    end

    Test.step "loads more when requested" do
      load_more_button = modal(page) |> Locator.get_by_role(:button, name: "Load more")

      Locator.scroll_into_view_if_needed!(load_more_button)
      Locator.click!(load_more_button)

      expect_metric_values(modal(page), "/page10/foo", ["10", "10", "100%", "-", "-"])

      expect_metric_values(modal(page), "/page1/foo", ["1", "1", "100%", "-", "-"])
    end

    Test.step "sorts when clicking on column header" do
      header(modal(page), "Visitors") |> Locator.click!()

      page_rows = for idx <- 0..99, do: "/page#{idx + 1}/foo"

      expect_rows(modal(page), page_rows)
    end

    Test.step "filters when using search" do
      search_input(modal(page)) |> Locator.fill!("page9")

      expect_rows(modal(page), [
        "/page9/foo",
        "/page90/foo",
        "/page91/foo",
        "/page92/foo",
        "/page93/foo",
        "/page94/foo",
        "/page95/foo",
        "/page96/foo",
        "/page97/foo",
        "/page98/foo",
        "/page99/foo"
      ])
    end

    Test.step "close button closes the modal" do
      close_modal_button(page) |> Locator.click!()

      Expect.to_be_hidden!(modal(page))
    end

    Test.step "reopening the modal resets the search state but preserves" do
      details_link(report) |> Locator.click!()

      Expect.to_contain_class!(modal(page), "is-open")

      Expect.to_have_value!(search_input(modal(page)), "")

      page_rows = for idx <- 0..99, do: "/page#{idx + 1}/foo"

      expect_rows(modal(page), page_rows)
    end
  end
end

defmodule PlausibleE2E.Dashboard.BreakdownsPagesGoalFilterTest do
  use PlausibleE2E.Case, async: true

  test "pages breakdown with a pageview goal filter applied", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{user_id: 123, name: "pageview", pathname: "/page1"},
        %{user_id: 123, name: "pageview", pathname: "/page2"},
        %{user_id: 123, name: "pageview", pathname: "/page3"},
        %{
          user_id: 123,
          name: "purchase",
          revenue_reporting_amount: "23",
          revenue_reporting_currency: "EUR"
        },
        %{user_id: 124, name: "pageview", pathname: "/page1"},
        %{user_id: 124, name: "pageview", pathname: "/page2"},
        %{user_id: 124, name: "create_site"},
        %{name: "pageview", pathname: "/page1"},
        %{name: "pageview", pathname: "/other"}
      ]
    )

    add_custom_goal(page: page, domain: domain, name: "create_site")
    add_custom_goal(page: page, domain: domain, name: "purchase", currency: "EUR")

    report = Page.get_by_test_id(page, "report-pages")

    Test.step "custom goal filter applied" do
      Page.goto!(page, "/" <> domain <> "?f=is,goal,create_site", wait_until: :commit)

      pages_tab_button = tab_button(report, "Conversion pages")
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(pages_tab_button, "data-active", "true")

      expect_headers(report, ["Page", "Conversions", "CR"])

      expect_rows(report, ["/"])

      expect_metric_values(report, "/", ["1", "50%"])
    end

    Test.step "details modal after custom goal filter applied" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Conversion pages")
      )

      expect_headers(modal(page), ["Page", ~r/Total visitors/, ~r/Conversions/, ~r/CR/])

      expect_rows(modal(page), ["/"])

      expect_metric_values(modal(page), "/", ["2", "1", "50%"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "revenue goal filter applied" do
      Page.goto!(page, "/" <> domain <> "?f=is,goal,purchase", wait_until: :commit)

      pages_tab_button = tab_button(report, "Conversion pages")
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(pages_tab_button, "data-active", "true")

      expect_headers(report, ["Page", "Conversions", "CR"])

      expect_rows(report, ["/"])

      expect_metric_values(report, "/", ["1", "50%"])
    end

    Test.step "details modal after revenue goal filter applied" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Conversion pages")
      )

      expect_headers(modal(page), [
        "Page",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), ["/"])

      expect_metric_values(modal(page), "/", ["2", "1", "50%", "€23.0", "€23.0"])

      close_modal_button(page) |> Locator.click!()
    end
  end
end

defmodule PlausibleE2E.Dashboard.BreakdownsPagesUrlModeTest do
  use PlausibleE2E.Case, async: true

  test "pages breakdown - URL mode", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{user_id: 1, name: "pageview", hostname: "blog.example.com", pathname: "/post"},
        %{user_id: 1, name: "pageview", hostname: "blog.example.com", pathname: "/post"},
        %{user_id: 2, name: "pageview", hostname: "blog.example.com", pathname: "/post"},
        %{user_id: 3, name: "pageview", hostname: "docs.example.com", pathname: "/api"}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)
    report = Page.get_by_test_id(page, "report-pages")

    Test.step "switch to URL mode" do
      report |> Locator.get_by_role(:button, name: "Breakdown options") |> Locator.click!()
      page |> Page.get_by_role(:button, name: "URL") |> Locator.click!()
    end

    Test.step "top pages in URL mode" do
      Expect.to_have_attribute!(tab_button(report, "Top pages"), "data-active", "true")

      expect_headers(report, ["URL", "Visitors"])
      expect_rows(report, ["blog.example.com/post", "docs.example.com/api"])
      expect_metric_values(report, "blog.example.com/post", ["2", "66.7%"])
      expect_metric_values(report, "docs.example.com/api", ["1", "33.3%"])
    end

    Test.step "clicking a URL mode row applies hostname and page filters" do
      row_link(report, "blog.example.com/post") |> Locator.click!()

      Expect.to_be_visible!(
        Page.get_by_role(page, :button, name: "Remove filter: Hostname is blog.example.com")
      )

      Expect.to_be_visible!(Page.get_by_role(page, :button, name: "Remove filter: Page is /post"))

      Page.get_by_role(page, :button, name: "Remove filter: Hostname is blog.example.com")
      |> Locator.click!()

      Page.get_by_role(page, :button, name: "Remove filter: Page is /post") |> Locator.click!()
    end

    Test.step "entry pages in URL mode" do
      tab_button(report, "Entry pages") |> Locator.click!()

      expect_headers(report, ["URL", "Unique entrances"])
      expect_rows(report, ["blog.example.com/post", "docs.example.com/api"])
      expect_metric_values(report, "blog.example.com/post", ["2", "66.7%"])
      expect_metric_values(report, "docs.example.com/api", ["1", "33.3%"])
    end

    Test.step "entry pages modal in URL mode" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Entry pages"))

      expect_headers(modal(page), [
        "URL",
        ~r/Unique entrances/,
        ~r/Total entrances/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["blog.example.com/post", "docs.example.com/api"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "exit pages in URL mode" do
      tab_button(report, "Exit pages") |> Locator.click!()

      expect_headers(report, ["URL", "Unique exits"])
      expect_rows(report, ["blog.example.com/post", "docs.example.com/api"])
    end

    Test.step "exit pages modal in URL mode" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Exit pages"))

      expect_headers(modal(page), ["URL", ~r/Unique exits/, ~r/Total exits/, ~r/Exit rate/])

      expect_rows(modal(page), ["blog.example.com/post", "docs.example.com/api"])

      close_modal_button(page) |> Locator.click!()
    end
  end
end
