defmodule PlausibleE2E.SiteSettings.FunnelSettingsTest do
  use PlausibleE2E.Case, async: true

  defp press(page, key), do: Keyboard.press!(Page.keyboard(page), key)

  defp form(page), do: Page.locator(page, "#funnel-form")

  defp step_input(page, n), do: Page.locator(page, "#step-#{n} input")

  defp step_option(page, n),
    do: Page.locator(page, "#step-#{n} .input-picker-dropdown-option")

  defp add_funnel_button(page), do: Page.get_by_role(page, :button, name: "Add funnel")

  # First escape press cancels focus on combobox input;
  # next one closes the modal.
  defp close_form(page) do
    press(page, "Escape")
    press(page, "Escape")

    Expect.to_be_hidden!(form(page))
  end

  describe "funnel settings" do
    test "form integration tests", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{user_id: 123, name: "Hello World", timestamp: %{hoursAgo: 60}},
          %{user_id: 123, name: "Plausible", timestamp: %{hoursAgo: 50}},
          %{user_id: 123, name: "Another World", timestamp: %{hoursAgo: 45}}
        ]
      )

      Page.goto!(page, "/#{domain}/settings/funnels", wait_until: :commit)
      expect_live_view_connected(page)

      Test.step "search reacts to the input the user types in" do
        Locator.click!(add_funnel_button(page))

        Expect.to_be_visible!(form(page))

        Locator.fill!(step_input(page, 1), "hello")

        Expect.to_be_visible!(step_option(page, 1) |> Locator.get_by_text("Hello World"))

        Locator.fill!(step_input(page, 1), "hello")

        Expect.to_be_visible!(step_option(page, 1) |> Locator.get_by_text("Plausible"))

        close_form(page)
      end

      Test.step "selecting option prefills input values" do
        Locator.click!(add_funnel_button(page))

        Expect.to_be_visible!(form(page))

        Locator.fill!(step_input(page, 1), "another")

        step_option(page, 1) |> Locator.get_by_text("Another World") |> Locator.click!()

        Expect.to_have_value!(step_input(page, 1), "Another World")

        close_form(page)
      end

      Test.step "selecting one option reduces suggestions in the other" do
        Locator.click!(add_funnel_button(page))

        Expect.to_be_visible!(form(page))

        Locator.fill!(step_input(page, 1), "another")

        step_option(page, 1) |> Locator.get_by_text("Another World") |> Locator.click!()

        Locator.fill!(step_input(page, 2), "a")

        Expect.to_be_hidden!(step_option(page, 2) |> Locator.get_by_text("Another World"))

        close_form(page)
      end

      Test.step "removing one option alters suggestions for other" do
        Locator.click!(add_funnel_button(page))

        Expect.to_be_visible!(form(page))

        Page.locator(page, "a[phx-click=add-step]") |> Locator.click!()

        Locator.fill!(step_input(page, 2), "hello")

        step_option(page, 2) |> Locator.get_by_text("Hello World") |> Locator.click!()

        Locator.fill!(step_input(page, 1), "hello")

        Expect.to_be_hidden!(step_option(page, 1) |> Locator.get_by_text("Hello World"))

        Page.locator(page, "#remove-step-2") |> Locator.click!()

        Locator.fill!(step_input(page, 1), "hello")

        Expect.to_be_visible!(step_option(page, 1) |> Locator.get_by_text("Hello World"))

        close_form(page)
      end
    end

    defp form_submission_events do
      [
        %{user_id: 123, name: "pageview", pathname: "/page1", timestamp: %{hoursAgo: 60}},
        %{
          user_id: 123,
          name: "Form: Submission",
          "meta.key": ["path"],
          "meta.value": ["/form-action/path"],
          timestamp: %{hoursAgo: 50}
        },
        %{user_id: 123, name: "pageview", pathname: "/page2", timestamp: %{hoursAgo: 45}}
      ]
    end

    test "save button saves a new funnel", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(request: request, domain: domain, events: form_submission_events())

      Page.goto!(page, "/#{domain}/settings/funnels", wait_until: :commit)
      expect_live_view_connected(page)

      Locator.click!(add_funnel_button(page))

      Expect.to_be_visible!(form(page))

      Expect.to_be_disabled!(Page.locator(page, "button#save"))

      Locator.fill!(step_input(page, 1), "page")

      step_option(page, 1) |> Locator.get_by_text("Visit /page1") |> Locator.click!()

      Expect.to_have_value!(step_input(page, 1), "Visit /page1")

      Locator.click!(step_input(page, 2))

      step_option(page, 2) |> Locator.get_by_text("Form: Submission") |> Locator.click!()

      Page.locator(page, "input#funnel_name") |> Locator.fill!("First funnel")

      Expect.to_be_enabled!(Page.locator(page, "button#save"))

      Page.locator(page, "button#save") |> Locator.click!()

      Expect.to_be_hidden!(form(page))

      Expect.to_contain_text!(Page.locator(page, "#funnel-settings-main table"), "First funnel")

      %{"name" => funnel_name, "steps" => [step1, step2]} =
        get_funnel(request: request, domain: domain, name: "First funnel")

      assert funnel_name == "First funnel"
      # dynamic step
      assert step1["id"] == 0
      assert step1["page_path"] == "/page1"
      # static step
      assert step2["id"] > 0
      assert step2["event_name"] == "Form: Submission"
    end

    test "clicking save after editing the funnel updates it", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      add_goal(request: request, domain: domain, params: %{page_path: "/page1"})
      add_goal(request: request, domain: domain, params: %{event_name: "Form: Submission"})

      populate_stats(
        request: request,
        domain: domain,
        events:
          form_submission_events() ++
            [
              %{user_id: 124, name: "pageview", pathname: "/page1", timestamp: %{hoursAgo: 60}},
              %{user_id: 124, name: "pageview", pathname: "/page2", timestamp: %{hoursAgo: 45}}
            ]
      )

      add_funnel(
        request: request,
        domain: domain,
        name: "Existing funnel",
        steps: ["Visit /page1", %{page_path: "/page2"}]
      )

      Page.goto!(page, "/#{domain}/settings/funnels", wait_until: :commit)
      expect_live_view_connected(page)

      Page.locator(page, "button[phx-click=edit-funnel]") |> Locator.click!()

      Expect.to_be_visible!(form(page))

      Locator.fill!(step_input(page, 2), "form")

      step_option(page, 2) |> Locator.get_by_text("Form: Submission") |> Locator.click!()

      Expect.to_have_value!(step_input(page, 2), "Form: Submission")

      Page.locator(page, "input#funnel_name") |> Locator.fill!("Updated funnel")

      Expect.to_be_enabled!(Page.locator(page, "button#save"))

      Page.locator(page, "button#save") |> Locator.click!()

      Expect.to_be_hidden!(form(page))

      %{"name" => funnel_name, "steps" => [step1, step2]} =
        get_funnel(request: request, domain: domain, name: "Updated funnel")

      assert funnel_name == "Updated funnel"
      # static step
      assert step1["id"] > 0
      assert step1["page_path"] == "/page1"
      # static step
      assert step2["id"] > 0
      assert step2["event_name"] == "Form: Submission"
    end

    test "funnel gets evaluated on every select, assuming a second has passed between selections",
         %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(request: request, domain: domain, events: form_submission_events())

      Page.goto!(page, "/#{domain}/settings/funnels", wait_until: :commit)
      expect_live_view_connected(page)

      Locator.click!(add_funnel_button(page))

      Expect.to_be_visible!(form(page))

      Locator.click!(step_input(page, 1))

      step_option(page, 1) |> Locator.first() |> Locator.click!()

      Expect.not_to_have_value!(step_input(page, 1), "")

      Locator.click!(step_input(page, 2))

      step_option(page, 2) |> Locator.first() |> Locator.click!()

      Expect.not_to_have_value!(step_input(page, 2), "")

      Expect.to_have_text!(Page.locator(page, "#step-eval-0"), "Visitors: 1")
      Expect.to_have_text!(Page.locator(page, "#step-eval-1"), "Dropoff: 100%")
      Expect.to_have_text!(Page.locator(page, "#funnel-eval"), "Last month conversion rate: 0%")
    end

    test "scroll goal can be picked for a matching pageview event from the previous step", %{
      page: page,
      request: request
    } do
      %{domain: domain} = setup_site(page: page, request: request)

      add_goal(
        request: request,
        domain: domain,
        params: %{page_path: "/page1", scroll_threshold: 90, display_name: "Scroll 90% on /page1"}
      )

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{user_id: 123, name: "pageview", pathname: "/page1", timestamp: %{minutesAgo: 1500}},
          %{
            user_id: 123,
            name: "engagement",
            pathname: "/page1",
            scroll_depth: 90,
            timestamp: %{minutesAgo: 1499}
          },
          %{user_id: 123, name: "pageview", pathname: "/page2", timestamp: %{minutesAgo: 1498}}
        ]
      )

      Page.goto!(page, "/#{domain}/settings/funnels", wait_until: :commit)
      expect_live_view_connected(page)

      Locator.click!(add_funnel_button(page))

      Expect.to_be_visible!(form(page))

      Locator.click!(step_input(page, 1))

      step_option(page, 1) |> Locator.get_by_text("Visit /page1") |> Locator.click!()

      Expect.to_have_value!(step_input(page, 1), "Visit /page1")

      Locator.click!(step_input(page, 2))

      Expect.to_be_visible!(step_option(page, 2) |> Locator.get_by_text("Scroll 90% on /page1"))
    end
  end
end
