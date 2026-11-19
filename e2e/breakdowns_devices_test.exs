defmodule PlausibleE2E.Dashboard.BreakdownsDevicesTest do
  use PlausibleE2E.Case, async: true

  test "devices breakdown", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          name: "pageview",
          screen_size: "Desktop",
          browser: "Chrome",
          browser_version: "14.0.7",
          operating_system: "Windows",
          operating_system_version: "11"
        },
        %{
          name: "pageview",
          screen_size: "Desktop",
          browser: "Firefox",
          browser_version: "98",
          operating_system: "MacOS",
          operating_system_version: "10.15"
        },
        %{
          name: "pageview",
          screen_size: "Mobile",
          browser: "Safari",
          browser_version: "123",
          operating_system: "iOS",
          operating_system_version: "16.15"
        }
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    report = Page.get_by_test_id(page, "report-devices")

    browsers_tab_button = tab_button(report, "Browsers")

    Test.step "browsers tab" do
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(browsers_tab_button, "data-active", "true")

      expect_headers(report, ["Browser", "Visitors"])

      expect_rows(report, ["Chrome", "Firefox", "Safari"])

      expect_metric_values(report, "Chrome", ["1", "33.3%"])
      expect_metric_values(report, "Firefox", ["1", "33.3%"])
      expect_metric_values(report, "Safari", ["1", "33.3%"])
    end

    Test.step "browsers modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Browsers"))

      expect_headers(modal(page), ["Browser", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), ["Chrome", "Firefox", "Safari"])

      expect_metric_values(modal(page), "Chrome", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "browser versions" do
      row_link(report, "Firefox") |> Locator.click!()

      Expect.to_have_url!(page, ~r/f=is,browser,Firefox/)

      Expect.to_have_attribute!(browsers_tab_button, "data-active", "true")

      expect_headers(report, ["Browser version", "Visitors"])

      expect_rows(report, ["Firefox 98"])

      expect_metric_values(report, "Firefox 98", ["1", "100%"])
    end

    Test.step "browser versions modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Browser versions")
      )

      expect_headers(modal(page), [
        "Browser version",
        ~r/Visitors/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["98"])

      expect_metric_values(modal(page), "98", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()

      Page.get_by_role(page, :button, name: "Remove filter: Browser is Firefox")
      |> Locator.click!()
    end

    os_tab_button = tab_button(report, "Operating systems")

    Test.step "operating systems tab" do
      Locator.click!(os_tab_button)
      Expect.to_have_attribute!(os_tab_button, "data-active", "true")

      expect_headers(report, ["Operating system", "Visitors"])

      expect_rows(report, ["MacOS", "Windows", "iOS"])

      expect_metric_values(report, "MacOS", ["1", "33.3%"])
      expect_metric_values(report, "Windows", ["1", "33.3%"])
      expect_metric_values(report, "iOS", ["1", "33.3%"])
    end

    Test.step "operating systems modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Operating systems")
      )

      expect_headers(modal(page), [
        "Operating system",
        ~r/Visitors/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["MacOS", "Windows", "iOS"])

      expect_metric_values(modal(page), "MacOS", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "operating system versions" do
      row_link(report, "Windows") |> Locator.click!()

      Expect.to_have_url!(page, ~r/f=is,os,Windows/)

      Expect.to_have_attribute!(os_tab_button, "data-active", "true")

      expect_headers(report, ["Operating system version", "Visitors"])

      expect_rows(report, ["Windows 11"])

      expect_metric_values(report, "Windows 11", ["1", "100%"])
    end

    Test.step "operating system versions modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Operating system versions")
      )

      expect_headers(modal(page), [
        "Operating system version",
        ~r/Visitors/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["11"])

      expect_metric_values(modal(page), "11", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()

      Page.get_by_role(page, :button, name: "Remove filter: Operating system is Windows")
      |> Locator.click!()
    end

    Test.step "devices tab" do
      devices_tab_button = tab_button(report, "Devices")
      Locator.click!(devices_tab_button)
      Expect.to_have_attribute!(devices_tab_button, "data-active", "true")

      expect_headers(report, ["Device", "Visitors"])

      expect_rows(report, ["Desktop", "Mobile"])

      expect_metric_values(report, "Desktop", ["2", "66.7%"])
      expect_metric_values(report, "Mobile", ["1", "33.3%"])
    end

    Test.step "devices modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Devices"))

      expect_headers(modal(page), ["Device", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), ["Desktop", "Mobile"])

      expect_metric_values(modal(page), "Desktop", ["2", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end
  end
end

defmodule PlausibleE2E.Dashboard.BreakdownsDevicesRevenueTest do
  use PlausibleE2E.Case, async: true

  test "devices breakdown with a revenue goal filter applied", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          user_id: 1,
          name: "pageview",
          screen_size: "Desktop",
          browser: "Chrome",
          browser_version: "14.0.7",
          operating_system: "Windows",
          operating_system_version: "11"
        },
        %{
          user_id: 1,
          name: "purchase",
          revenue_reporting_amount: "23",
          revenue_reporting_currency: "EUR"
        },
        %{
          user_id: 2,
          name: "pageview",
          screen_size: "Desktop",
          browser: "Chrome",
          browser_version: "14.0.7",
          operating_system: "Windows",
          operating_system_version: "11"
        },
        %{
          user_id: 3,
          name: "pageview",
          screen_size: "Mobile",
          browser: "Firefox",
          browser_version: "98",
          operating_system: "MacOS",
          operating_system_version: "10.15"
        },
        %{
          user_id: 3,
          name: "purchase",
          revenue_reporting_amount: "12345.67",
          revenue_reporting_currency: "EUR"
        }
      ]
    )

    add_custom_goal(page: page, domain: domain, name: "purchase", currency: "EUR")

    Page.goto!(page, "/" <> domain <> "?f=is,goal,purchase", wait_until: :commit)

    report = Page.get_by_test_id(page, "report-devices")

    Test.step "browsers report shows conversions for revenue goal" do
      tab_button(report, "Browsers") |> Locator.click!()
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

      expect_headers(report, ["Browser", "Conversions", "CR"])

      expect_rows(report, ["Chrome", "Firefox"])

      expect_metric_values(report, "Chrome", ["1", "50%"])
      expect_metric_values(report, "Firefox", ["1", "100%"])
    end

    Test.step "browsers details modal includes revenue columns" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Browsers"))

      expect_headers(modal(page), [
        "Browser",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), ["Chrome", "Firefox"])

      expect_metric_values(modal(page), "Chrome", ["2", "1", "50%", "€23.0", "€23.0"])
      expect_metric_values(modal(page), "Firefox", ["1", "1", "100%", "€12.3K", "€12.3K"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "browser versions report shows conversions for revenue goal" do
      row_link(report, "Chrome") |> Locator.click!()

      Expect.to_have_url!(page, ~r/f=is,browser,Chrome/)

      expect_headers(report, ["Browser version", "Conversions", "CR"])

      expect_rows(report, ["Chrome 14.0.7"])

      expect_metric_values(report, "Chrome 14.0.7", ["1", "50%"])
    end

    Test.step "browser versions details modal includes revenue columns" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Browser versions")
      )

      expect_headers(modal(page), [
        "Browser version",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), ["14.0.7"])

      expect_metric_values(modal(page), "14.0.7", ["2", "1", "50%", "€23.0", "€23.0"])

      close_modal_button(page) |> Locator.click!()

      Page.get_by_role(page, :button, name: "Remove filter: Browser is Chrome")
      |> Locator.click!()
    end

    Test.step "operating systems report shows conversions for revenue goal" do
      tab_button(report, "Operating systems") |> Locator.click!()

      expect_headers(report, ["Operating system", "Conversions", "CR"])

      expect_rows(report, ["MacOS", "Windows"])

      expect_metric_values(report, "MacOS", ["1", "100%"])
      expect_metric_values(report, "Windows", ["1", "50%"])
    end

    Test.step "operating systems details modal includes revenue columns" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Operating systems")
      )

      expect_headers(modal(page), [
        "Operating system",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), ["MacOS", "Windows"])

      expect_metric_values(modal(page), "MacOS", ["1", "1", "100%", "€12.3K", "€12.3K"])
      expect_metric_values(modal(page), "Windows", ["2", "1", "50%", "€23.0", "€23.0"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "operating system versions report shows conversions for revenue goal" do
      row_link(report, "Windows") |> Locator.click!()

      Expect.to_have_url!(page, ~r/f=is,os,Windows/)

      expect_headers(report, ["Operating system version", "Conversions", "CR"])

      expect_rows(report, ["Windows 11"])

      expect_metric_values(report, "Windows 11", ["1", "50%"])
    end

    Test.step "operating system versions details modal includes revenue columns" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Operating system versions")
      )

      expect_headers(modal(page), [
        "Operating system version",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), ["11"])

      expect_metric_values(modal(page), "11", ["2", "1", "50%", "€23.0", "€23.0"])

      close_modal_button(page) |> Locator.click!()

      Page.get_by_role(page, :button, name: "Remove filter: Operating system is Windows")
      |> Locator.click!()
    end

    Test.step "devices report shows conversions for revenue goal" do
      tab_button(report, "Devices") |> Locator.click!()

      expect_headers(report, ["Device", "Conversions", "CR"])

      expect_rows(report, ["Desktop", "Mobile"])

      expect_metric_values(report, "Desktop", ["1", "50%"])
      expect_metric_values(report, "Mobile", ["1", "100%"])
    end

    Test.step "devices details modal includes revenue columns" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Devices"))

      expect_headers(modal(page), [
        "Device",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), ["Desktop", "Mobile"])

      expect_metric_values(modal(page), "Desktop", ["2", "1", "50%", "€23.0", "€23.0"])
      expect_metric_values(modal(page), "Mobile", ["1", "1", "100%", "€12.3K", "€12.3K"])

      close_modal_button(page) |> Locator.click!()
    end
  end
end
