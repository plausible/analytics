defmodule PlausibleE2E.Dashboard.BehavioursFunnelsTest do
  use PlausibleE2E.Case, async: true

  defp get_report(page), do: Page.get_by_test_id(page, "report-behaviours")

  test "funnels", %{page: page, request: request} do
    report = get_report(page)
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/products",
          timestamp: %{minutesAgo: 60}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/cart",
          timestamp: %{minutesAgo: 55}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/checkout",
          timestamp: %{minutesAgo: 50}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/products",
          timestamp: %{minutesAgo: 55}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/cart",
          timestamp: %{minutesAgo: 50}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/products",
          timestamp: %{minutesAgo: 50}
        }
      ]
    )

    add_pageview_goal(page: page, domain: domain, pathname: "/products")
    add_pageview_goal(page: page, domain: domain, pathname: "/cart")
    add_pageview_goal(page: page, domain: domain, pathname: "/checkout")

    for idx <- 0..10 do
      add_funnel(
        request: request,
        domain: domain,
        name: "Shopping #{idx + 1} Funnel",
        steps: ["Visit /products", "Visit /cart", "Visit /checkout"]
      )
    end

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    funnels_tab_button = tab_button_with_dropdown(report, "Funnels")

    Test.step "rendering funnels" do
      Locator.click!(funnels_tab_button)
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

      dropdown(report)
      |> Locator.get_by_role(:button, name: "Shopping 11 Funnel")
      |> Locator.click!()

      funnels_tab_button
      |> tab_button("Funnels")
      |> Expect.to_have_attribute!("data-active", "true")

      report |> Locator.get_by_role(:heading) |> Expect.to_have_text!("Shopping 11 Funnel")

      Expect.to_be_visible!(Locator.get_by_text(report, "3-step funnel"))

      Expect.to_be_visible!(Locator.get_by_text(report, "Sequential"))

      Expect.to_be_visible!(Locator.get_by_text(report, ~r/Conversion rate:\s*33\.3%/))

      steps = Locator.locator(report, ~s|[data-testid^="funnel-step-"]|)
      Expect.to_have_count!(steps, 3)
      Expect.to_contain_text!(Locator.nth(steps, 0), "Visit /products")
      Expect.to_contain_text!(Locator.nth(steps, 0), "100%")
      Expect.to_contain_text!(Locator.nth(steps, 2), "33.3%")

      outcome = steps |> Locator.nth(1) |> Locator.get_by_role(:button)
      Expect.to_have_accessible_name!(outcome, ~r/continued .* dropped off/)

      Expect.not_to_have_attribute!(outcome, "data-open")
      Locator.click!(outcome)
      Expect.to_have_attribute!(outcome, "data-open", "true")
    end

    Test.step "loading more" do
      expect_dropdown_closed(report)
      Locator.click!(funnels_tab_button)
      show_more_button = dropdown(report) |> Locator.get_by_role(:button, name: "Show 1 more")
      Locator.click!(show_more_button)
      Expect.to_be_hidden!(show_more_button)
      Expect.to_have_count!(dropdown(report) |> Locator.get_by_role(:button), 11)

      dropdown(report)
      |> Locator.get_by_role(:button, name: "Shopping 1 Funnel")
      |> Locator.click!()

      report |> Locator.get_by_role(:heading) |> Expect.to_have_text!("Shopping 1 Funnel")
    end

    Test.step "searching" do
      expect_dropdown_closed(report)
      Locator.click!(funnels_tab_button)
      report |> search_input() |> Locator.fill!("Shopping 1")

      dropdown(report)
      |> Locator.get_by_role(:button)
      |> Expect.to_have_text!(["Shopping 11 Funnel", "Shopping 10 Funnel", "Shopping 1 Funnel"])
    end
  end

  test "funnels - comparisons", %{page: page, request: request} do
    report = get_report(page)
    %{domain: domain} = setup_site(page: page, request: request)

    thirty_days = 30 * 24 * 60
    yesterday = 24 * 60

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          user_id: 120,
          name: "pageview",
          pathname: "/products",
          timestamp: %{minutesAgo: thirty_days + 60}
        },
        %{
          user_id: 120,
          name: "pageview",
          pathname: "/cart",
          timestamp: %{minutesAgo: thirty_days + 55}
        },
        %{
          user_id: 120,
          name: "pageview",
          pathname: "/checkout",
          timestamp: %{minutesAgo: thirty_days + 50}
        },
        %{
          user_id: 121,
          name: "pageview",
          pathname: "/products",
          timestamp: %{minutesAgo: thirty_days + 55}
        },
        %{
          user_id: 121,
          name: "pageview",
          pathname: "/cart",
          timestamp: %{minutesAgo: thirty_days + 50}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/products",
          timestamp: %{minutesAgo: yesterday + 60}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/cart",
          timestamp: %{minutesAgo: yesterday + 55}
        },
        %{
          user_id: 123,
          name: "pageview",
          pathname: "/checkout",
          timestamp: %{minutesAgo: yesterday + 50}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/products",
          timestamp: %{minutesAgo: yesterday + 55}
        },
        %{
          user_id: 124,
          name: "pageview",
          pathname: "/cart",
          timestamp: %{minutesAgo: yesterday + 50}
        },
        %{
          user_id: 125,
          name: "pageview",
          pathname: "/products",
          timestamp: %{minutesAgo: yesterday + 50}
        }
      ]
    )

    add_pageview_goal(page: page, domain: domain, pathname: "/products")
    add_pageview_goal(page: page, domain: domain, pathname: "/cart")
    add_pageview_goal(page: page, domain: domain, pathname: "/checkout")

    add_funnel(
      request: request,
      domain: domain,
      name: "Shopping Funnel",
      steps: ["Visit /products", "Visit /cart", "Visit /checkout"]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    funnels_tab_button = tab_button_with_dropdown(report, "Funnels")

    Test.step "rendering funnels" do
      Locator.click!(funnels_tab_button)
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()

      dropdown(report)
      |> Locator.get_by_role(:button, name: "Shopping Funnel")
      |> Locator.click!()

      funnels_tab_button
      |> tab_button("Funnels")
      |> Expect.to_have_attribute!("data-active", "true")

      # enable compare
      Keyboard.press!(Page.keyboard(page), "x")

      report |> Locator.get_by_role(:heading) |> Expect.to_have_text!("Shopping Funnel")

      Expect.to_be_visible!(Locator.get_by_text(report, "3-step funnel"))

      Expect.to_be_visible!(Locator.get_by_text(report, "Sequential"))

      Expect.to_be_visible!(Locator.get_by_text(report, ~r/Conversion rate:\s*33\.3%/))

      report
      |> Locator.get_by_test_id("change-arrow")
      |> Locator.first()
      |> Expect.to_have_text!("16.7%")

      steps = Locator.locator(report, ~s|[data-testid^="funnel-step-"]|)
      Expect.to_have_count!(steps, 3)
      step0 = Locator.nth(steps, 0)
      Expect.to_contain_text!(step0, "Visit /products")
      Expect.to_contain_text!(step0, "100% entered")
      Expect.to_contain_text!(step0, "3 visitors")
      Expect.to_contain_text!(step0, "2 visitors")
      step1 = Locator.nth(steps, 1)
      Expect.to_contain_text!(step1, "Visit /cart")
      Expect.to_contain_text!(step1, "66.7% continued")
      Expect.to_contain_text!(step1, "100% continued")
      Expect.to_contain_text!(step1, "2 visitors")
      step2 = Locator.nth(steps, 2)
      Expect.to_contain_text!(step2, "Visit /checkout")
      Expect.to_contain_text!(step2, "33.3%")
      Expect.to_contain_text!(step2, "50% converted")
    end
  end
end
