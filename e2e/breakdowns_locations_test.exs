defmodule PlausibleE2E.Dashboard.BreakdownsLocationsTest do
  use PlausibleE2E.Case, async: true

  test "locations breakdown", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          name: "pageview",
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        },
        %{
          name: "pageview",
          country_code: "EE",
          subdivision1_code: "EE-79",
          city_geoname_id: 588_335
        },
        %{
          name: "pageview",
          country_code: "PL",
          subdivision1_code: "PL-14",
          city_geoname_id: 756_135
        },
        %{name: "pageview", country_code: ""}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    report = Page.get_by_test_id(page, "report-locations")

    Test.step "map tab" do
      map_tab_button = tab_button(report, "Map")
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(map_tab_button, "data-active", "true")

      # NOTE: We only check that the map is there
      report |> Locator.locator("svg path.country") |> Locator.first() |> Expect.to_be_visible!()
    end

    Test.step "countries tab" do
      countries_tab_button = tab_button(report, "Countries")
      Locator.click!(countries_tab_button)
      Expect.to_have_attribute!(countries_tab_button, "data-active", "true")

      expect_headers(report, ["Country", "Visitors"])

      expect_rows(report, [~r/Estonia/, ~r/Poland/])

      expect_metric_values(report, "Estonia", ["2", "66.7%"])
      expect_metric_values(report, "Poland", ["1", "33.3%"])
    end

    Test.step "countries modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Countries"))

      expect_headers(modal(page), ["Country", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), [~r/Estonia/, ~r/Poland/])

      expect_metric_values(modal(page), "Estonia", ["2", "100%", "0s"])

      Expect.to_be_visible!(search_input(modal(page)))

      search_input(modal(page)) |> Locator.fill!("Esto")
      expect_rows(modal(page), [~r/Estonia/])

      search_input(modal(page)) |> Locator.fill!("")
      expect_rows(modal(page), [~r/Estonia/, ~r/Poland/])

      close_modal_button(page) |> Locator.click!()
    end

    regions_tab_button = tab_button(report, "Regions")

    Test.step "clicking country entry shows regions" do
      row_link(report, "Estonia") |> Locator.click!()
      Expect.to_have_url!(page, ~r/f=is,country,EE/)

      Expect.to_have_attribute!(regions_tab_button, "data-active", "true")

      Page.get_by_role(page, :button, name: "Remove filter: Country is Estonia")
      |> Locator.click!()
    end

    Test.step "regions tab" do
      Locator.click!(regions_tab_button)
      Expect.to_have_attribute!(regions_tab_button, "data-active", "true")

      expect_headers(report, ["Region", "Visitors"])

      expect_rows(report, [~r/Harjumaa/, ~r/Mazovia/, ~r/Tartumaa/])

      expect_metric_values(report, "Harjumaa", ["1", "33.3%"])
      expect_metric_values(report, "Tartumaa", ["1", "33.3%"])
      expect_metric_values(report, "Mazovia", ["1", "33.3%"])
    end

    Test.step "regions modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Regions"))

      expect_headers(modal(page), ["Region", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), [~r/Harjumaa/, ~r/Mazovia/, ~r/Tartumaa/])

      expect_metric_values(modal(page), "Harjumaa", ["1", "100%", "0s"])

      Expect.to_be_visible!(search_input(modal(page)))

      search_input(modal(page)) |> Locator.fill!("Harju")
      expect_rows(modal(page), [~r/Harjumaa/])

      search_input(modal(page)) |> Locator.fill!("")
      expect_rows(modal(page), [~r/Harjumaa/, ~r/Mazovia/, ~r/Tartumaa/])

      close_modal_button(page) |> Locator.click!()
    end

    cities_tab_button = tab_button(report, "Cities")

    Test.step "clicking region entry shows cities" do
      row_link(report, "Harjumaa") |> Locator.click!()
      Expect.to_have_url!(page, ~r/f=is,region,EE-37/)

      Expect.to_have_attribute!(cities_tab_button, "data-active", "true")

      Page.get_by_role(page, :button, name: "Remove filter: Region is Harjumaa")
      |> Locator.click!()
    end

    Test.step "cities tab" do
      Locator.click!(cities_tab_button)
      Expect.to_have_attribute!(cities_tab_button, "data-active", "true")

      expect_headers(report, ["City", "Visitors"])

      expect_rows(report, [~r/Tallinn/, ~r/Tartu/, ~r/Warsaw/])

      expect_metric_values(report, "Tartu", ["1", "33.3%"])
      expect_metric_values(report, "Tallinn", ["1", "33.3%"])
      expect_metric_values(report, "Warsaw", ["1", "33.3%"])
    end

    Test.step "cities modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Cities"))

      expect_headers(modal(page), ["City", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), [~r/Tallinn/, ~r/Tartu/, ~r/Warsaw/])

      expect_metric_values(modal(page), "Tartu", ["1", "100%", "0s"])

      Expect.to_be_visible!(search_input(modal(page)))

      search_input(modal(page)) |> Locator.fill!("Tallinn")
      expect_rows(modal(page), [~r/Tallinn/])

      search_input(modal(page)) |> Locator.fill!("")
      expect_rows(modal(page), [~r/Tallinn/, ~r/Tartu/, ~r/Warsaw/])

      close_modal_button(page) |> Locator.click!()
    end
  end
end

defmodule PlausibleE2E.Dashboard.BreakdownsLocationsRevenueTest do
  use PlausibleE2E.Case, async: true

  test "locations breakdown with a revenue goal filter applied", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{user_id: 1, name: "pageview", country_code: "A1"},
        %{user_id: 2, name: "pageview", country_code: "A1"},
        %{
          user_id: 2,
          name: "purchase",
          revenue_reporting_amount: "23",
          revenue_reporting_currency: "EUR",
          country_code: "A1"
        },
        %{
          user_id: 3,
          name: "pageview",
          country_code: "PL",
          subdivision1_code: "PL-14",
          city_geoname_id: 756_135
        },
        %{
          user_id: 4,
          name: "pageview",
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        },
        %{
          user_id: 4,
          name: "purchase",
          revenue_reporting_amount: "12345.67",
          revenue_reporting_currency: "EUR",
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        }
      ]
    )

    add_custom_goal(page: page, domain: domain, name: "purchase", currency: "EUR")

    Page.goto!(page, "/" <> domain <> "?f=is,goal,purchase", wait_until: :commit)

    report = Page.get_by_test_id(page, "report-locations")

    Test.step "countries report shows conversions for revenue goal" do
      tab_button(report, "Countries") |> Locator.click!()
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

      expect_headers(report, ["Country", "Conversions", "CR"])

      expect_rows(report, [~r/Anonymous VPN Service/, ~r/Estonia/])

      expect_metric_values(report, "Anonymous VPN Service", ["1", "50%"])
      expect_metric_values(report, "Estonia", ["1", "100%"])
    end

    Test.step "countries details modal includes revenue columns" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Countries"))

      expect_headers(modal(page), [
        "Country",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), [~r/Anonymous VPN Service/, ~r/Estonia/])

      expect_metric_values(modal(page), "Anonymous VPN Service", [
        "2",
        "1",
        "50%",
        "€23.0",
        "€23.0"
      ])

      expect_metric_values(modal(page), "Estonia", ["1", "1", "100%", "€12.3K", "€12.3K"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "regions report shows conversions for revenue goal" do
      tab_button(report, "Regions") |> Locator.click!()

      expect_headers(report, ["Region", "Conversions", "CR"])

      expect_rows(report, [~r/Harjumaa/])

      expect_metric_values(report, "Harjumaa", ["1", "100%"])
    end

    Test.step "regions details modal includes revenue columns" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Regions"))

      expect_headers(modal(page), [
        "Region",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), [~r/Harjumaa/])

      expect_metric_values(modal(page), "Harjumaa", ["1", "1", "100%", "€12.3K", "€12.3K"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "cities report shows conversions for revenue goal" do
      tab_button(report, "Cities") |> Locator.click!()

      expect_headers(report, ["City", "Conversions", "CR"])

      expect_rows(report, [~r/Tallinn/])

      expect_metric_values(report, "Tallinn", ["1", "100%"])
    end

    Test.step "cities details modal includes revenue columns" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Cities"))

      expect_headers(modal(page), [
        "City",
        ~r/Total visitors/,
        ~r/Conversions/,
        ~r/CR/,
        ~r/Revenue/,
        ~r/Average/
      ])

      expect_rows(modal(page), [~r/Tallinn/])

      expect_metric_values(modal(page), "Tallinn", ["1", "1", "100%", "€12.3K", "€12.3K"])

      close_modal_button(page) |> Locator.click!()
    end
  end
end
