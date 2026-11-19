defmodule PlausibleE2E.Dashboard.FilteringVisitorTest do
  use PlausibleE2E.Case, async: true

  describe "location filtering tests" do
    defp open_location_filter(page, item), do: open_filter_submenu_item(page, "Location", item)

    test "filtering by location", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{
            name: "pageview",
            country_code: "EE",
            subdivision1_code: "EE-37",
            city_geoname_id: 588_409,
            browser: "Chrome"
          }
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Test.step "filtering by country" do
        Locator.click!(filter_button(page))
        open_location_filter(page, "Country")

        pick_filter_value(page, search: "est", value: "Estonia")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Country is Estonia"))

        Expect.to_have_url!(page, ~r/f=is,country,EE/)
      end

      Test.step "filtering by region" do
        Locator.click!(filter_button(page))
        open_location_filter(page, "Region")

        pick_filter_value(page, search: "har", value: "Harjumaa")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Region is Harjumaa"))

        Expect.to_have_url!(page, ~r/f=is,region,EE-37/)
        Expect.to_have_url!(page, ~r/f=is,country,EE/)
      end

      Test.step "filtering by city" do
        Locator.click!(filter_button(page))
        open_location_filter(page, "City")

        pick_filter_value(page, value: "Tallinn")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "City is Tallinn"))

        Expect.to_have_url!(page, ~r/f=is,city,588409/)
        Expect.to_have_url!(page, ~r/f=is,region,EE-37/)
        Expect.to_have_url!(page, ~r/f=is,country,EE/)
      end
    end
  end

  describe "screen size filtering tests" do
    defp screen_size_filter_button(page), do: filter_item_button(page, "Screen size")

    test "filtering by screen size", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{name: "pageview", screen_size: "Desktop"},
          %{name: "pageview", screen_size: "Mobile"}
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Locator.click!(filter_button(page))
      Locator.click!(screen_size_filter_button(page))

      # When testing via test.e2e.ui, it shows there are no
      # suggestions found but there are 2 pageview in the top stats.
      # When navigating live via `MIX_ENV=e2e_test iex -S mix`,
      # all works fine. Puzzling.
      pick_filter_value(page, search: "mob", value: "Mobile")
      close_filter_editor(page)

      Expect.to_be_visible!(filter_pill(page, "Screen size is Mobile"))

      Expect.to_have_url!(page, ~r/f=is,screen,Mobile/)
    end
  end

  describe "browser filtering tests" do
    defp open_browser_filter(page, item), do: open_filter_submenu_item(page, "Browser", item)

    test "filtering by browser", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{name: "pageview", browser: "Chrome", browser_version: "14.0.7"},
          %{name: "pageview", browser: "Firefox", browser_version: "98"}
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Test.step "filtering by browser type" do
        Locator.click!(filter_button(page))
        open_browser_filter(page, "Browser")

        pick_filter_value(page, search: "chrom", value: "Chrome")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Browser is Chrome"))

        Expect.to_have_url!(page, ~r/f=is,browser,Chrome/)
      end

      Test.step "filtering by browser version" do
        Locator.click!(filter_button(page))
        open_browser_filter(page, "Browser version")

        pick_filter_value(page, search: "14", value: "14.0.7")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Browser version is 14.0.7"))

        Expect.to_have_url!(page, ~r/f=is,browser_version,14\.0\.7/)
        Expect.to_have_url!(page, ~r/f=is,browser,Chrome/)
      end
    end
  end

  describe "operating system filtering tests" do
    defp open_operating_system_filter(page, item),
      do: open_filter_submenu_item(page, "Operating system", item)

    test "filtering by operating system", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{
            name: "pageview",
            operating_system: "Windows",
            operating_system_version: "11",
            browser: "Chrome",
            browser_version: "14.0.7"
          },
          %{name: "pageview", operating_system: "MacOS", operating_system_version: "10.15"}
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Test.step "filtering by operating system type" do
        Locator.click!(filter_button(page))
        open_operating_system_filter(page, "Operating system")

        # The same problem as in the case of screen size filter test.
        pick_filter_value(page, value: "Windows")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Operating system is Windows"))

        Expect.to_have_url!(page, ~r/f=is,os,Windows/)
      end

      Test.step "filtering by operating system version" do
        Locator.click!(filter_button(page))
        open_operating_system_filter(page, "Operating system version")

        pick_filter_value(page, value: "11")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Operating system version is 11"))

        Expect.to_have_url!(page, ~r/f=is,os_version,11/)
        Expect.to_have_url!(page, ~r/f=is,os,Windows/)
      end
    end
  end
end
