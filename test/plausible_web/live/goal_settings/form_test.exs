defmodule PlausibleWeb.Live.GoalSettings.FormTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  on_ee do
  end

  @revenue_goal_settings ~s|div[data-test-id="revenue-goal-settings"]|

  describe "integration - live rendering" do
    setup [:create_user, :log_in, :create_site]

    test "form renders with custom events when selected from dropdown", %{conn: conn, site: site} do
      setup_goals(site)
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      html = render(lv)

      assert html =~ "Add goal for #{site.domain}"
      refute element_exists?(html, "#pageviews-form")
      refute element_exists?(html, "#scroll-form")
      assert element_exists?(html, "#custom-events-form")

      assert html =~ "Event name"
    end

    test "form renders with pageview when selected from dropdown", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("pageviews")

      html = render(lv)

      assert html =~ "Add goal for #{site.domain}"
      refute element_exists?(html, "#custom-events-form")
      refute element_exists?(html, "#scroll-form")
      assert element_exists?(html, "#pageviews-form")
      assert html =~ "Page path"
    end

    test "form renders with scroll when selected from dropdown", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("scroll")

      html = render(lv)

      assert html =~ "Add goal for #{site.domain}"
      refute element_exists?(html, "#custom-events-form")
      refute element_exists?(html, "#pageviews-form")
      assert element_exists?(html, "#scroll-form")
      assert html =~ "Scroll percentage threshold"
      assert html =~ "Page path"
    end
  end

  describe "Goal submission" do
    setup [:create_user, :log_in, :create_site]

    @tag :ee_only
    test "renders form fields for custom events with currency", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      html = render(lv)

      refute element_exists?(html, "#pageviews-form")

      input_names = html |> find("#custom-events-form input") |> Enum.map(&name_of/1)

      assert "goal[event_name]" in input_names
      assert "goal[display_name]" in input_names
      assert "goal[custom_props][keys][]" in input_names
      assert "goal[custom_props][values][]" in input_names
      assert "display-currency_input_modalseq0" in input_names
    end

    test "renders form fields for pageview", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("pageviews")

      html = render(lv)

      refute element_exists?(html, "#custom-events-form")

      input_names = html |> find("#pageviews-form input") |> Enum.map(&name_of/1)

      assert "display-page_path_input_modalseq0" in input_names
      assert "goal[page_path]" in input_names
      assert "goal[display_name]" in input_names
      assert "goal[custom_props][keys][]" in input_names
      assert "goal[custom_props][values][]" in input_names
    end

    @tag :ce_build_only
    test "renders form fields for custom events (no currency)", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      html = render(lv)

      refute element_exists?(html, "#pageviews-form")

      input_names = html |> find("#custom-events-form input") |> Enum.map(&name_of/1)

      assert "goal[event_name]" in input_names
      assert "goal[display_name]" in input_names
      assert "goal[custom_props][keys][]" in input_names
      assert "goal[custom_props][values][]" in input_names
      refute "display-currency_input_modalseq0" in input_names
    end

    test "renders error on empty submission", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      lv |> element("#goals-form-modalseq0 form") |> render_submit()
      html = render(lv)
      assert html =~ "this field is required and cannot be blank"
    end

    test "renders error on empty pageview submission", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("pageviews")

      lv |> element("#goals-form-modalseq0 form") |> render_submit()
      html = render(lv)
      assert html =~ "this field is required and must start with a /"
    end

    test "creates a custom event", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")
      refute render(lv) =~ "SampleCustomEvent"

      lv = open_modal_with_goal_type(lv, "custom_events")

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{event_name: "SampleCustomEvent"}})

      html = render(lv)
      assert html =~ "SampleCustomEvent"
      assert html =~ "Custom Event"
    end

    on_ee do
      test "creates a custom event for consolidated view (revenue switch not available)", %{
        conn: conn,
        user: user
      } do
        {:ok, team} = Plausible.Teams.get_or_create(user)
        new_site(team: team)
        site = new_consolidated_view(team)

        lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

        assert render(lv) =~ "Add goal for consolidated view"
        refute element_exists?(render(lv), @revenue_goal_settings)

        lv
        |> element("#goals-form-modalseq0 form")
        |> render_submit(%{goal: %{event_name: "SampleCustomEvent"}})

        html = render(lv)
        assert html =~ "SampleCustomEvent"
        assert html =~ "Custom Event"
      end
    end

    @tag :ee_only
    test "creates a revenue goal", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")
      refute render(lv) =~ "SampleRevenueGoal"

      assert element_exists?(render(lv), @revenue_goal_settings)

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{
        goal: %{
          event_name: "SampleRevenueGoal",
          currency: "EUR",
          display_name: "Sample Display Name"
        }
      })

      html = render(lv)

      assert html =~ "SampleRevenueGoal"
      assert html =~ "Revenue Goal (EUR)"
      assert html =~ "Sample Display Name"
    end

    test "creates a pageview goal", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("pageviews")
      refute render(lv) =~ "Visit /page/**"

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{page_path: "/page/**"}})

      html = render(lv)
      assert html =~ "Visit /page/**"
      assert html =~ "Pageview"

      assert Plausible.Goals.count(site) == 1
    end

    test "fails to create a goal above limit", %{conn: conn, site: site} do
      for i <- 1..10, do: {:ok, _} = Plausible.Goals.create(site, %{"event_name" => "G#{i}"})

      lv = get_liveview(conn, site) |> open_modal_with_goal_type("pageviews")
      refute render(lv) =~ "Visit /page/**"

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{page_path: "/page/**"}})

      html = render(lv)
      assert html =~ "Maximum number of goals reached"

      assert Plausible.Goals.count(site) == 10
    end
  end

  describe "Editing goals" do
    setup [:create_user, :log_in, :create_site]

    @tag :ee_only
    test "tabless view is rendered with goal type change disabled", %{conn: conn, site: site} do
      {:ok, [pageview, custom_event, revenue_goal]} = setup_goals(site)
      lv = get_liveview(conn, site)

      # pageviews
      lv |> element(~s/button#edit-goal-#{pageview.id}/) |> render_click()
      html = render(lv)

      assert element_exists?(html, "#pageviews-form")
      refute element_exists?(html, "#custom-events-form")

      refute element_exists?(
               html,
               ~s/button[role=switch][aria-labelledby=enable-revenue-tracking]/
             )

      # custom events
      lv |> element(~s/button#edit-goal-#{custom_event.id}/) |> render_click()
      html = render(lv)

      refute element_exists?(html, "#pageviews-form")
      assert element_exists?(html, "#custom-events-form")
      refute String.downcase(text_of_element(html, "#custom-events-form")) =~ "currency"

      # revenue goals
      lv |> element(~s/button#edit-goal-#{revenue_goal.id}/) |> render_click()
      html = render(lv)

      refute element_exists?(html, "#pageviews-form")
      assert element_exists?(html, "#custom-events-form")
      assert element_exists?(html, ~s/[data-test-id=goal-currency-label]/)
    end

    test "updates a custom event", %{conn: conn, site: site} do
      {:ok, [_, g, _]} = setup_goals(site)
      lv = get_liveview(conn, site)

      lv |> element(~s/button#edit-goal-#{g.id}/) |> render_click()

      html = render(lv)
      assert element_exists?(html, "#event_name_input_modalseq0[value=Signup]")

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{event_name: "Updated", display_name: "UPDATED"}})

      _html = render(lv)

      updated = Plausible.Goals.get(site, g.id)
      assert updated.event_name == "Updated"
      assert updated.display_name == "UPDATED"
      assert updated.id == g.id
    end

    @tag :ee_only
    test "updates a revenue goal", %{conn: conn, site: site} do
      {:ok, [_, _, g]} = setup_goals(site)
      lv = get_liveview(conn, site)

      lv |> element(~s/button#edit-goal-#{g.id}/) |> render_click()

      html = render(lv)
      assert element_exists?(html, "#event_name_input_modalseq0[value=Purchase]")
      assert element_exists?(html, ~s/#currency_input_modalseq0[value="EUR - Euro"]/)

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{event_name: "Updated", currency: "USD"}})

      _html = render(lv)

      updated = Plausible.Goals.get(site, g.id)
      assert updated.event_name == "Updated"
      assert updated.display_name == "Purchase"
      assert updated.currency == :USD
      assert updated.currency != g.currency
      assert updated.id == g.id
    end

    test "updates a pageview", %{conn: conn, site: site} do
      {:ok, [g, _, _]} = setup_goals(site)
      lv = get_liveview(conn, site)

      lv |> element(~s/button#edit-goal-#{g.id}/) |> render_click()

      html = render(lv)
      assert element_exists?(html, ~s|#page_path_input_modalseq0[value="/go/to/blog/**"]|)

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{page_path: "/updated", display_name: "Visit /updated"}})

      _html = render(lv)

      updated = Plausible.Goals.get(site, g.id)
      assert updated.page_path == "/updated"
      assert updated.display_name == "Visit /updated"
      assert updated.id == g.id
    end

    test "renders error when goal is invalid", %{conn: conn, site: site} do
      {:ok, [g, g2, _]} = setup_goals(site)
      lv = get_liveview(conn, site)

      lv |> element(~s/button#edit-goal-#{g.id}/) |> render_click()

      html = render(lv)
      assert element_exists?(html, ~s|#page_path_input_modalseq0[value="/go/to/blog/**"]|)

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{page_path: "/updated", display_name: g2.display_name}})

      html = render(lv)

      assert html =~ "has already been taken"
    end

    test "hides 'Add custom property' toggle when editing goal with custom props", %{
      conn: conn,
      site: site
    } do
      {:ok, goal} =
        Plausible.Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"product" => "Shirt", "color" => "Blue"}
        })

      lv = get_liveview(conn, site)
      lv |> element(~s/button#edit-goal-#{goal.id}/) |> render_click()

      html = render(lv)

      refute html =~ "Add custom property"
      assert html =~ "Custom properties"
    end

    test "shows 'Add custom property' toggle when editing goal without custom props", %{
      conn: conn,
      site: site
    } do
      {:ok, goal} = Plausible.Goals.create(site, %{"event_name" => "Signup"})

      lv = get_liveview(conn, site)
      lv |> element(~s/button#edit-goal-#{goal.id}/) |> render_click()

      html = render(lv)

      assert html =~ "Add custom property"
      refute html =~ "Custom properties"
    end

    test "property pairs section is visible when editing goal with custom props", %{
      conn: conn,
      site: site
    } do
      {:ok, goal} =
        Plausible.Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"product" => "Shirt"}
        })

      lv = get_liveview(conn, site)
      lv |> element(~s/button#edit-goal-#{goal.id}/) |> render_click()

      html = render(lv)

      assert html =~ "Custom properties"
      assert element_exists?(html, ~s/[data-test-id="custom-property-pairs"]/)
    end
  end

  describe "Combos integration" do
    setup [:create_user, :log_in, :create_site]

    @tag :ee_only
    test "currency combo works", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      type_into_combo(lv, "currency_input_modalseq0", "Polish")
      html = render(lv)

      assert element_exists?(html, ~s/a[phx-value-display-value="PLN - Polish Zloty"]/)
      refute element_exists?(html, ~s/a[phx-value-display-value="EUR - Euro"]/)

      type_into_combo(lv, "currency_input_modalseq0", "Euro")
      html = render(lv)

      refute element_exists?(html, ~s/a[phx-value-display-value="PLN - Polish Zloty"]/)
      assert element_exists?(html, ~s/a[phx-value-display-value="EUR - Euro"]/)
    end

    test "pageview combo works", %{conn: conn, site: site} do
      lv = get_liveview(conn, site) |> open_modal_with_goal_type("pageviews")

      html = type_into_combo(lv, "page_path_input_modalseq0", "/hello")

      assert html =~ "Create &quot;/hello&quot;"
    end

    test "pageview combo uses filter suggestions", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/go/to/page/1"),
        build(:pageview, pathname: "/go/home")
      ])

      lv = get_liveview(conn, site) |> open_modal_with_goal_type("pageviews")

      type_into_combo(lv, "page_path_input_modalseq0", "/go/to/p")

      html = render(lv)
      assert html =~ "Create &quot;/go/to/p&quot;"
      assert html =~ "/go/to/page/1"
      refute html =~ "/go/home"

      type_into_combo(lv, "page_path_input_modalseq0", "/go/h")
      html = render(lv)
      assert html =~ "/go/home"
      refute html =~ "/go/to/page/1"
    end

    test "pageview combo considers imported pageviews as well", %{conn: conn, site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:imported_pages, page: "/go/to/page/1", pageviews: 2),
        build(:imported_pages, page: "/go/home", pageviews: 1)
      ])

      lv = get_liveview(conn, site) |> open_modal_with_goal_type("pageviews")

      type_into_combo(lv, "page_path_input_modalseq0", "/go/to/p")

      html = render(lv)
      assert html =~ "Create &quot;/go/to/p&quot;"
      assert html =~ "/go/to/page/1"
      refute html =~ "/go/home"

      type_into_combo(lv, "page_path_input_modalseq0", "/go/h")
      html = render(lv)
      assert html =~ "/go/home"
      refute html =~ "/go/to/page/1"
    end

    test "event name combo suggestions update on input", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "EventOne"),
        build(:event, name: "EventTwo"),
        build(:event, name: "EventThree")
      ])

      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      lv
      |> element("button[phx-click='add-manually']")
      |> render_click()

      type_into_combo(lv, "event_name_input_modalseq0", "One")
      html = render(lv)

      assert text_of_element(html, "#goals-form-modalseq0") =~ "EventOne"
      refute text_of_element(html, "#goals-form-modalseq0") =~ "EventTwo"
      refute text_of_element(html, "#goals-form-modalseq0") =~ "EventThree"
    end

    test "event name combo suggestions are up to date after deletion", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "EventOne")
      insert(:goal, site: site, event_name: "EventTwo")
      insert(:goal, site: site, event_name: "EventThree")

      populate_stats(site, [
        build(:event, name: "EventOne"),
        build(:event, name: "EventTwo"),
        build(:event, name: "EventThree")
      ])

      lv = get_liveview(conn, site)

      # Delete the goal
      goal = Plausible.Repo.get_by(Plausible.Goal, site_id: site.id, event_name: "EventOne")

      lv |> element(~s/button#delete-goal-#{goal.id}/) |> render_click()
      lv |> element("button[phx-click='add-manually']") |> render_click()

      html = render(lv)

      assert text_of_element(html, "#goals-form-modalseq0") =~ "EventOne"
      refute text_of_element(html, "#goals-form-modalseq0") =~ "EventTwo"
      refute text_of_element(html, "#goals-form-modalseq0") =~ "EventThree"
    end
  end

  describe "Autoconfigure goals from custom events modal" do
    setup [:create_user, :log_in, :create_site]

    test "shows autoconfigure modal when opening custom events modal with available events", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/go/home"),
        build(:event, name: "Signup"),
        build(:event, name: "Newsletter Signup"),
        build(:event, name: "Purchase")
      ])

      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      html = render(lv)
      assert html =~ "We detected 3 custom"
      assert html =~ "These events have been sent from your site in the past 6 months"
    end

    test "clicking 'Add manually' shows the regular form", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/go/home"),
        build(:event, name: "Signup"),
        build(:event, name: "Newsletter Signup"),
        build(:event, name: "Purchase")
      ])

      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      html = render(lv)
      assert html =~ "We detected 3 custom"

      lv
      |> element("button[phx-click='add-manually']")
      |> render_click()

      html = render(lv)
      refute html =~ "We detected"
      assert html =~ "Add goal for"
    end

    test "autoconfigure button adds all events", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/go/home"),
        build(:event, name: "Signup"),
        build(:event, name: "Newsletter Signup"),
        build(:event, name: "Purchase")
      ])

      lv = get_liveview(conn, site) |> open_modal_with_goal_type("custom_events")

      lv
      |> element("button[phx-click='autoconfigure']")
      |> render_click()

      # Render again to process the async :autoconfigure message
      _html = render(lv)

      goals = Plausible.Goals.for_site(site)
      assert length(goals) == 3
      assert Enum.any?(goals, &(&1.event_name == "Signup"))
      assert Enum.any?(goals, &(&1.event_name == "Newsletter Signup"))
      assert Enum.any?(goals, &(&1.event_name == "Purchase"))
    end

    test "autoconfigure modal does not show when all events are already goals", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, pathname: "/go/home"),
        build(:event, name: "Signup"),
        build(:event, name: "Newsletter Signup"),
        build(:event, name: "Purchase")
      ])

      lv = get_liveview(conn, site)
      html = render(lv)

      assert element_exists?(html, "[data-test-id='autoconfigure-modal']")

      lv
      |> element("button[phx-click='autoconfigure']")
      |> render_click()

      html = render(lv)
      refute element_exists?(html, "[data-test-id='autoconfigure-modal']")

      lv = open_modal_with_goal_type(lv, "custom_events")
      html = render(lv)

      refute element_exists?(html, "[data-test-id='autoconfigure-modal']")
      refute html =~ "We detected"
      refute html =~ "from the last 6 months"
    end
  end

  defp type_into_combo(lv, id, text) do
    lv
    |> element("input##{id}")
    |> render_change(%{
      "_target" => ["display-#{id}"],
      "display-#{id}" => "#{text}"
    })
  end

  defp setup_goals(site) do
    {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/go/to/blog/**"})
    {:ok, g2} = Plausible.Goals.create(site, %{"event_name" => "Signup"})
    {:ok, g3} = Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})
    {:ok, [g1, g2, g3]}
  end

  defp get_liveview(conn, site) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.GoalSettings)
    {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/goals")

    lv
  end

  defp open_modal_with_goal_type(lv, goal_type) do
    lv
    |> element(~s/[phx-click="add-goal"][phx-value-goal-type="#{goal_type}"]/)
    |> render_click()

    lv
  end
end
