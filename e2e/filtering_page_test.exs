defmodule PlausibleE2E.Dashboard.FilteringPageTest do
  use PlausibleE2E.Case, async: true

  describe "page filtering tests" do
    defp open_page_filter(page, item), do: open_filter_submenu_item(page, "Page", item)

    test "filtering by page with detailed behavior test", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{name: "pageview", pathname: "/page1"},
          %{name: "pageview", pathname: "/page2"},
          %{name: "pageview", pathname: "/page3"},
          %{name: "pageview", pathname: "/other"}
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Locator.click!(filter_button(page))
      open_page_filter(page, "Page")

      Expect.to_be_visible!(filter_pill(page, "Page is"))
      Expect.to_be_focused!(filter_value_search(page))

      Locator.fill!(filter_value_search(page), "page")

      Expect.to_be_visible!(filter_value_option(page, "/page1"))
      Expect.to_be_visible!(filter_value_option(page, "/page2"))
      Expect.to_be_visible!(filter_value_option(page, "/page3"))
      Expect.not_to_have_url!(page, ~r/f=/)

      Locator.fill!(filter_value_search(page), "/page1")

      Expect.to_be_visible!(filter_value_option(page, "/page1"))
      Expect.to_be_hidden!(filter_value_option(page, "/page2"))

      Locator.click!(filter_value_option(page, "/page1"))

      Expect.to_have_url!(page, ~r|f=is,page,/page1|)
      Expect.to_have_attribute!(filter_value_option(page, "/page1"), "aria-selected", "true")

      close_filter_editor(page)

      Expect.to_have_attribute!(
        filter_pill_values_button(page, "Page is /page1"),
        "title",
        "Page is /page1"
      )
    end

    test "filtering by page using different operators", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{name: "pageview", pathname: "/page1"},
          %{name: "pageview", pathname: "/page2"},
          %{name: "pageview", pathname: "/page3"},
          %{name: "pageview", pathname: "/other"}
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Test.step "'is not' operator" do
        Locator.click!(filter_button(page))
        open_page_filter(page, "Page")

        Locator.click!(filter_pill_operator_button(page, "Page is"))
        Locator.click!(filter_operator_option(page, "is not"))
        pick_filter_value(page, search: "page", value: "/page1")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Page is not /page1"))

        Expect.to_have_url!(page, ~r|f=is_not,page,/page1|)

        Page.get_by_role(page, :button, name: "Remove filter: Page is not /page1")
        |> Locator.click!()

        Expect.not_to_have_url!(page, ~r|f=is_not,page,/page1|)
      end

      Test.step "'contains' operator" do
        Locator.click!(filter_button(page))
        open_page_filter(page, "Page")

        Locator.click!(filter_pill_operator_button(page, "Page is"))
        Locator.click!(filter_operator_option(page, "contains"))
        pick_filter_value(page, search: "page1", value: "Filter by 'page1'")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Page contains page1"))

        Expect.to_have_url!(page, ~r/f=contains,page,page1/)

        Page.get_by_role(page, :button, name: "Remove filter: Page contains page1")
        |> Locator.click!()

        Expect.not_to_have_url!(page, ~r/f=contains,page,page1/)
      end

      Test.step "'does not contain' operator" do
        Locator.click!(filter_button(page))
        open_page_filter(page, "Page")

        Locator.click!(filter_pill_operator_button(page, "Page is"))
        Locator.click!(filter_operator_option(page, "does not contain"))
        pick_filter_value(page, search: "page1", value: "Filter by 'page1'")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Page does not contain page1"))

        Expect.to_have_url!(page, ~r/f=contains_not,page,page1/)

        Page.get_by_role(page, :button, name: "Remove filter: Page does not contain page1")
        |> Locator.click!()

        Expect.not_to_have_url!(page, ~r/f=contains_not,page,page1/)
      end

      Test.step "'is' operator with multiple choices" do
        Locator.click!(filter_button(page))
        open_page_filter(page, "Page")

        pick_filter_value(page, search: "page", value: "/page2")
        pick_filter_value(page, value: "/page3")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Page is /page2 or /page3"))

        Expect.to_have_url!(page, ~r|f=is,page,/page2,/page3|)
      end

      Test.step "editing the values and the operator of a filter" do
        Locator.click!(filter_pill_values_button(page, "Page is /page2 or /page3"))

        Expect.to_have_attribute!(filter_value_option(page, "/page2"), "aria-selected", "true")
        Locator.click!(filter_value_option(page, "/page2"))
        Expect.to_have_url!(page, ~r|f=is,page,/page3(&\|$)|)

        close_filter_editor(page)
        Expect.to_be_visible!(filter_pill(page, "Page is /page3"))

        Locator.click!(filter_pill_operator_button(page, "Page is /page3"))
        Locator.click!(filter_operator_option(page, "is not"))

        Expect.to_be_visible!(filter_pill(page, "Page is not /page3"))
        Expect.to_have_url!(page, ~r|f=is_not,page,/page3|)
      end
    end

    test "filtering by entry page", %{page: page, request: request} do
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

      Locator.click!(filter_button(page))
      open_page_filter(page, "Entry page")

      pick_filter_value(page, search: "page", value: "/page1")
      close_filter_editor(page)

      Expect.to_be_visible!(filter_pill(page, "Entry page is /page1"))

      Expect.to_have_url!(page, ~r|f=is,entry_page,/page1|)
    end

    test "filtering by exit page", %{page: page, request: request} do
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

      Locator.click!(filter_button(page))
      open_page_filter(page, "Exit page")

      pick_filter_value(page, search: "page", value: "/page3")
      close_filter_editor(page)

      Expect.to_be_visible!(filter_pill(page, "Exit page is /page3"))

      Expect.to_have_url!(page, ~r|f=is,exit_page,/page3|)
    end
  end
end
