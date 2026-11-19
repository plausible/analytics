defmodule PlausibleE2E.Dashboard.FilteringGoalPropertyTest do
  use PlausibleE2E.Case, async: true

  describe "goal filtering tests" do
    defp goal_filter_button(page), do: filter_item_button(page, "Goal")

    test "filtering by goals", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{name: "pageview", pathname: "/page1"},
          %{name: "pageview", pathname: "/page2"}
        ]
      )

      add_pageview_goal(page: page, domain: domain, pathname: "/page1")
      add_pageview_goal(page: page, domain: domain, pathname: "/page2")

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Test.step "single goal filter" do
        Locator.click!(filter_button(page))
        Locator.click!(goal_filter_button(page))

        pick_filter_value(page, search: "page1", value: "Visit /page1")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Goal is Visit /page1"))

        Expect.to_have_url!(page, ~r|f=is,goal,Visit%20/page1|)
      end

      Test.step "multiple goal filters" do
        Locator.click!(filter_button(page))
        Locator.click!(goal_filter_button(page))

        Expect.to_be_visible!(filter_pill(page, "Goal is"))

        Locator.click!(filter_pill_operator_button(page, "Goal is"))
        Locator.click!(filter_operator_option(page, "is not"))
        pick_filter_value(page, search: "page2", value: "Visit /page2")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Goal is Visit /page1"))
        Expect.to_be_visible!(filter_pill(page, "Goal is not Visit /page2"))

        Expect.to_have_url!(page, ~r|f=is,goal,Visit%20/page1|)
        Expect.to_have_url!(page, ~r|f=has_not_done,goal,Visit%20/page2|)
      end
    end
  end

  describe "property filtering tests" do
    test "filtering by properties", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{
            name: "pageview",
            "meta.key": ["logged_in", "browser_language"],
            "meta.value": ["false", "en_US"]
          },
          %{
            name: "pageview",
            "meta.key": ["logged_in", "browser_language"],
            "meta.value": ["true", "es"]
          }
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Test.step "single property filter" do
        Locator.click!(filter_button(page))
        open_property_keys(page)

        Locator.fill!(property_key_search(page), "logged")
        Locator.click!(property_key_option(page, "logged_in"))

        Expect.to_be_visible!(filter_pill(page, "Property 'logged_in' is"))

        pick_filter_value(page, search: "false", value: "false")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Property 'logged_in' is false"))

        Expect.to_have_url!(page, ~r/f=is,props:logged_in,false/)
      end

      Test.step "multiple property filters" do
        Locator.click!(filter_button(page))
        open_property_keys(page)

        Locator.fill!(property_key_search(page), "logged")
        Expect.to_have_attribute!(property_key_option(page, "logged_in"), "aria-disabled", "true")

        Locator.fill!(property_key_search(page), "browser")
        Locator.click!(property_key_option(page, "browser_language"))

        Locator.click!(filter_pill_operator_button(page, "Property 'browser_language' is"))
        Locator.click!(filter_operator_option(page, "is not"))
        pick_filter_value(page, search: "US", value: "en_US")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Property 'logged_in' is false"))

        Expect.to_be_visible!(filter_pill(page, "Property 'browser_language' is not en_US"))

        Expect.to_have_url!(page, ~r/f=is,props:logged_in,false/)
        Expect.to_have_url!(page, ~r/f=is_not,props:browser_language,en_US/)
      end
    end
  end
end
