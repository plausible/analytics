defmodule PlausibleWeb.Live.GoalSettings.FormTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "integration - live rendering" do
    setup [:create_user, :log_in, :create_site]

    test "tabs switching", %{conn: conn, site: site} do
      setup_goals(site)
      lv = get_liveview(conn, site)

      html = lv |> render()

      assert element_exists?(html, ~s/a#pageview-tab/)
      assert element_exists?(html, ~s/a#event-tab/)

      pageview_tab = lv |> element(~s/a#pageview-tab/) |> render_click()
      assert pageview_tab =~ "Page Path"

      event_tab = lv |> element(~s/a#event-tab/) |> render_click()
      assert event_tab =~ "Event Name"
    end

    test "can navigate to scroll tab if scroll_depth feature visible for site/user",
         %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      lv |> element(~s/a#scroll-tab/) |> render_click()
      html = render(lv)
      input_names = html |> find("#scroll-form input") |> Enum.map(&name_of/1)
      assert "goal[scroll_threshold]" in input_names
      assert "goal[page_path]" in input_names
      assert "goal[display_name]" in input_names
    end
  end

  describe "Goal submission" do
    setup [:create_user, :log_in, :create_site]

    @tag :ee_only
    test "renders form fields per tab, with currency", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = render(lv)

      refute element_exists?(html, "#pageviews-form")

      input_names = html |> find("#custom-events-form input") |> Enum.map(&name_of/1)

      assert input_names ==
               [
                 "display-event_name_input_modalseq0-tabseq0",
                 "goal[event_name]",
                 "goal[display_name]",
                 "display-currency_input_modalseq0-tabseq0",
                 "goal[currency]"
               ]

      lv |> element(~s/a#pageview-tab/) |> render_click()
      html = lv |> render()

      refute element_exists?(html, "#custom-events-form")

      input_names = html |> find("#pageviews-form input") |> Enum.map(&name_of/1)

      assert input_names == [
               "display-page_path_input_modalseq0-tabseq1",
               "goal[page_path]",
               "goal[display_name]"
             ]
    end

    @tag :ce_build_only
    test "renders form fields per tab (no currency)", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = render(lv)

      refute element_exists?(html, "#pageviews-form")

      input_names = html |> find("#custom-events-form input") |> Enum.map(&name_of/1)

      assert input_names ==
               [
                 "display-event_name_input_modalseq0-tabseq0",
                 "goal[event_name]",
                 "goal[display_name]"
               ]

      lv |> element(~s/a#pageview-tab/) |> render_click()
      html = lv |> render()

      refute element_exists?(html, "#custom-events-form")

      input_names = html |> find("#pageviews-form input") |> Enum.map(&name_of/1)

      assert input_names == [
               "display-page_path_input_modalseq0-tabseq1",
               "goal[page_path]",
               "goal[display_name]"
             ]
    end

    test "renders error on empty submission", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      lv |> element("#goals-form-modalseq0 form") |> render_submit()
      html = render(lv)
      assert html =~ "this field is required and cannot be blank"

      pageview_tab = lv |> element(~s/a#pageview-tab/) |> render_click()
      assert pageview_tab =~ "this field is required and must start with a /"
    end

    test "creates a custom event", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      refute render(lv) =~ "SampleCustomEvent"

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{event_name: "SampleCustomEvent"}})

      html = render(lv)
      assert html =~ "SampleCustomEvent"
      assert html =~ "Custom Event"
    end

    @tag :ee_only
    test "creates a revenue goal", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      refute render(lv) =~ "SampleRevenueGoal"

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
      lv = get_liveview(conn, site)
      refute render(lv) =~ "Visit /page/**"

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{page_path: "/page/**"}})

      html = render(lv)
      assert html =~ "Visit /page/**"
      assert html =~ "Pageview"
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

      assert element_exists?(
               html,
               ~s/button[role=switch][aria-labelledby=enable-revenue-tracking][disabled="disabled"]/
             )

      # revenue goals
      lv |> element(~s/button#edit-goal-#{revenue_goal.id}/) |> render_click()
      html = render(lv)

      refute element_exists?(html, "#pageviews-form")
      assert element_exists?(html, "#custom-events-form")

      assert element_exists?(
               html,
               ~s/button[role=switch][aria-labelledby=enable-revenue-tracking][disabled="disabled"]/
             )
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
      assert element_exists?(html, ~s|#page_path_input_modalseq0[value="/go/to/blog/**"|)

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
      assert element_exists?(html, ~s|#page_path_input_modalseq0[value="/go/to/blog/**"|)

      lv
      |> element("#goals-form-modalseq0 form")
      |> render_submit(%{goal: %{page_path: "/updated", display_name: g2.display_name}})

      html = render(lv)

      assert html =~ "has already been taken"
    end
  end

  describe "Combos integration" do
    setup [:create_user, :log_in, :create_site]

    @tag :ee_only
    test "currency combo works", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      type_into_combo(lv, "currency_input_modalseq0-tabseq0", "Polish")
      html = render(lv)

      assert element_exists?(html, ~s/a[phx-value-display-value="PLN - Polish Zloty"]/)
      refute element_exists?(html, ~s/a[phx-value-display-value="EUR - Euro"]/)

      type_into_combo(lv, "currency_input_modalseq0-tabseq0", "Euro")
      html = render(lv)

      refute element_exists?(html, ~s/a[phx-value-display-value="PLN - Polish Zloty"]/)
      assert element_exists?(html, ~s/a[phx-value-display-value="EUR - Euro"]/)
    end

    test "pageview combo works", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      lv |> element(~s/a#pageview-tab/) |> render_click()

      html = type_into_combo(lv, "page_path_input_modalseq0-tabseq1", "/hello")

      assert html =~ "Create &quot;/hello&quot;"
    end

    test "pageview combo uses filter suggestions", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/go/to/page/1"),
        build(:pageview, pathname: "/go/home")
      ])

      lv = get_liveview(conn, site)
      lv |> element(~s/a#pageview-tab/) |> render_click()

      type_into_combo(lv, "page_path_input_modalseq0-tabseq1", "/go/to/p")

      html = render(lv)
      assert html =~ "Create &quot;/go/to/p&quot;"
      assert html =~ "/go/to/page/1"
      refute html =~ "/go/home"

      type_into_combo(lv, "page_path_input_modalseq0-tabseq1", "/go/h")
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

      lv = get_liveview(conn, site)
      lv |> element(~s/a#pageview-tab/) |> render_click()

      type_into_combo(lv, "page_path_input_modalseq0-tabseq1", "/go/to/p")

      html = render(lv)
      assert html =~ "Create &quot;/go/to/p&quot;"
      assert html =~ "/go/to/page/1"
      refute html =~ "/go/home"

      type_into_combo(lv, "page_path_input_modalseq0-tabseq1", "/go/h")
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

      lv = get_liveview(conn, site)

      type_into_combo(lv, "event_name_input_modalseq0-tabseq0", "One")
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
      html = lv |> element(~s/button#delete-goal-#{goal.id}/) |> render_click()

      assert text_of_element(html, "#goals-form-modalseq0") =~ "EventOne"
      refute text_of_element(html, "#goals-form-modalseq0") =~ "EventTwo"
      refute text_of_element(html, "#goals-form-modalseq0") =~ "EventThree"
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
end
