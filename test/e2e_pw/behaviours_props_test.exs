defmodule PlausibleE2E.Dashboard.BehavioursPropsTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.BehavioursHelpers

  test "props breakdown", %{page: page, request: request} do
    report = report(page)
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          name: "pageview",
          pathname: "/page",
          timestamp: %{minutesAgo: 15},
          "meta.key": [
            "logged_in",
            "browser_language",
            "prop3",
            "prop4",
            "prop5",
            "prop6",
            "prop7",
            "prop8",
            "prop9",
            "prop10",
            "prop11"
          ],
          "meta.value": [
            "false",
            "en_US",
            "val3",
            "val4",
            "val5",
            "val6",
            "val7",
            "val8",
            "val9",
            "val10",
            "val11"
          ]
        },
        %{
          name: "pageview",
          pathname: "/page",
          timestamp: %{minutesAgo: 1},
          "meta.key": ["logged_in", "browser_language"],
          "meta.value": ["false", "en_US"]
        },
        %{
          name: "pageview",
          pathname: "/page",
          timestamp: %{minutesAgo: 2},
          "meta.key": ["logged_in", "browser_language"],
          "meta.value": ["true", "es"]
        }
      ]
    )

    add_pageview_goal(page: page, domain: domain, pathname: "/page")

    add_all_custom_props(page: page, domain: domain)

    Page.goto!(page, "/#{domain}?period=all", wait_until: :commit)

    props_tab_button = tab_button_with_dropdown(report, "Properties")

    Test.step "listing props" do
      Locator.click!(props_tab_button)
      scroll_to_end(report)

      dropdown(report)
      |> Locator.get_by_role(:button, name: "browser_language")
      |> Locator.click!()

      props_tab_button |> tab_button("Properties") |> expect_active()

      expect_headers(report, ["browser_language", "Visitors", "Events", "%"])

      expect_rows(report, ["en_US", "es"])

      expect_metric_values(report, "en_US", ["2", "2", "66.7%"])
      expect_metric_values(report, "es", ["1", "1", "33.3%"])
    end

    Test.step "loading more" do
      expect_dropdown_closed(report)
      Locator.click!(props_tab_button)
      show_more_button = dropdown(report) |> Locator.get_by_role(:button, name: "Show 1 more")
      Locator.click!(show_more_button)
      Expect.to_be_hidden!(show_more_button)
      Expect.to_have_count!(dropdown(report) |> Locator.get_by_role(:button), 11)
    end

    Test.step "searching" do
      report |> search_input() |> Locator.fill!("prop1")
      Expect.to_have_count!(dropdown(report) |> Locator.get_by_role(:button), 2)
    end

    Test.step "props modal" do
      Locator.click!(props_tab_button)
      expect_dropdown_closed(report)
      report |> details_link() |> Locator.click!()

      expect_modal_heading(page, "Custom property breakdown")

      expect_headers(modal(page), ["browser_language", ~r/Visitors/, ~r/Events/, ~r/%/])

      expect_rows(modal(page), ["en_US", "es"])

      expect_metric_values(modal(page), "en_US", ["2", "2", "66.7%"])

      close_modal(page)
    end

    Test.step "clicking goal opens props" do
      goals_tab_button = tab_button(report, "Goals")
      # the JS doesn't await this click
      Locator.click!(goals_tab_button)

      expect_active(goals_tab_button)

      row_link(report, "Visit /page") |> Locator.click!()

      props_tab_button |> tab_button("Properties") |> expect_active()

      expect_headers(report, ["browser_language", "Visitors", "Events", "CR"])

      expect_rows(report, ["en_US", "es"])

      expect_metric_values(report, "en_US", ["2", "2", "66.7%"])
      expect_metric_values(report, "es", ["1", "1", "33.3%"])
    end

    Page.goto!(page, "/" <> domain <> "?period=realtime", wait_until: :commit)
    scroll_to_end(report)

    Test.step "realtime props index breakdown displays stats from last 5min" do
      Locator.click!(props_tab_button)

      dropdown(report)
      |> Locator.get_by_role(:button, name: "browser_language")
      |> Locator.click!()

      Expect.to_be_hidden!(Locator.get_by_text(report, last_30min_pill()))

      expect_headers(report, ["browser_language", "Visitors", "Events", "%"])

      expect_rows(report, ["en_US", "es"])
      expect_metric_values(report, "en_US", ["1", "1", "50%"])
    end

    Test.step "realtime props details modal displays stats from last 5min" do
      report |> details_link() |> Locator.click!()

      expect_modal_heading(page, "Custom property breakdown")

      expect_rows(modal(page), ["en_US", "es"])
      expect_metric_values(modal(page), "en_US", ["1", "1", "50%"])

      close_modal(page)
    end
  end
end
