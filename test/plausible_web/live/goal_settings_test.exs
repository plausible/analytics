defmodule PlausibleWeb.Live.GoalSettingsTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "GET /:domain/settings/goals" do
    setup [:create_user, :log_in, :create_site]

    @tag :ee_only
    test "lists goals for the site and renders links", %{conn: conn, site: site} do
      {:ok, [g1, g2, g3]} = setup_goals(site)
      conn = get(conn, "/#{site.domain}/settings/goals")

      resp = html_response(conn, 200)
      assert resp =~ "Define actions that you want your users to take"
      assert resp =~ "compose Goals into Funnels"
      assert resp =~ "/#{URI.encode_www_form(site.domain)}/settings/funnels"
      assert element_exists?(resp, ~s|a[href="https://plausible.io/docs/goal-conversions"]|)

      assert resp =~ to_string(g1)
      assert resp =~ "Pageview"
      assert resp =~ to_string(g2)
      assert resp =~ "Custom Event"
      assert resp =~ to_string(g3)
      assert resp =~ "Revenue Goal (EUR)"
    end

    @tag :ee_only
    test "lists Revenue Goals with feature availability annotation if the plan does not cover them",
         %{conn: conn, user: user, site: site} do
      {:ok, [_, _, g3]} = setup_goals(site)

      user
      |> Plausible.Auth.User.end_trial()
      |> Plausible.Repo.update!()

      conn = get(conn, "/#{site.domain}/settings/goals")

      resp = html_response(conn, 200)

      assert g3.currency
      assert resp =~ to_string(g3)
      assert resp =~ "Unlock Revenue Goals by upgrading to a business plan"

      refute element_exists?(
               resp,
               ~s/button[phx-click="edit-goal"][phx-value-goal-id=#{g3.id}][disabled]#edit-goal-#{g3.id}/
             )
    end

    test "lists goals with actions", %{conn: conn, site: site} do
      {:ok, goals} = setup_goals(site)
      conn = get(conn, "/#{site.domain}/settings/goals")
      resp = html_response(conn, 200)

      for g <- goals do
        assert element_exists?(
                 resp,
                 ~s/button[phx-click="delete-goal"][phx-value-goal-id=#{g.id}]#delete-goal-#{g.id}/
               )

        assert element_exists?(
                 resp,
                 ~s/button[phx-click="edit-goal"][phx-value-goal-id=#{g.id}]#edit-goal-#{g.id}/
               )
      end
    end

    test "if no goals are present, a proper info is displayed", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/goals")
      resp = html_response(conn, 200)
      assert resp =~ "No goals configured for this site"
    end

    test "if goals are present, no info about missing goals is displayed", %{
      conn: conn,
      site: site
    } do
      {:ok, _goals} = setup_goals(site)
      conn = get(conn, "/#{site.domain}/settings/goals")
      resp = html_response(conn, 200)
      refute resp =~ "No goals configured for this site"
    end

    test "add goal button is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/goals")
      resp = html_response(conn, 200)
      assert element_exists?(resp, ~s/button#add-goal-button[phx-click="add-goal"]/)
    end

    test "search goals input is rendered", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/goals")
      resp = html_response(conn, 200)
      assert element_exists?(resp, ~s/input[type="text"]#filter-text/)
      assert element_exists?(resp, ~s/form[phx-change="filter"]#filter-form/)
    end
  end

  describe "GoalSettings live view" do
    setup [:create_user, :log_in, :create_site]

    test "allows goal deletion", %{conn: conn, site: site} do
      {:ok, [g1, g2 | _]} = setup_goals(site)
      {lv, html} = get_liveview(conn, site, with_html?: true)

      assert html =~ to_string(g1)
      assert html =~ to_string(g2)

      html = lv |> element(~s/button#delete-goal-#{g1.id}/) |> render_click()

      refute html =~ to_string(g1)
      assert html =~ to_string(g2)

      html = get(conn, "/#{site.domain}/settings/goals") |> html_response(200)

      refute html =~ to_string(g1)
      assert html =~ to_string(g2)
    end

    test "allows list filtering / search", %{conn: conn, site: site} do
      {:ok, [g1, g2, g3]} = setup_goals(site)
      {lv, html} = get_liveview(conn, site, with_html?: true)

      assert html =~ to_string(g1)
      assert html =~ to_string(g2)
      assert html =~ to_string(g3)

      html = type_into_search(lv, to_string(g3))

      refute html =~ to_string(g1)
      refute html =~ to_string(g2)
      assert html =~ to_string(g3)
    end

    test "allows resetting filter text via backspace icon", %{conn: conn, site: site} do
      {:ok, [g1, g2, g3]} = setup_goals(site)
      {lv, html} = get_liveview(conn, site, with_html?: true)

      refute element_exists?(html, ~s/svg[phx-click="reset-filter-text"]#reset-filter/)

      html = type_into_search(lv, to_string(g3))

      assert element_exists?(html, ~s/svg[phx-click="reset-filter-text"]#reset-filter/)

      html = lv |> element(~s/svg#reset-filter/) |> render_click()

      assert html =~ to_string(g1)
      assert html =~ to_string(g2)
      assert html =~ to_string(g3)
    end

    test "allows resetting filter text via no match link", %{conn: conn, site: site} do
      {:ok, _goals} = setup_goals(site)
      lv = get_liveview(conn, site)
      html = type_into_search(lv, "Definitely this is not going to render any matches")

      assert html =~ "No goals found for this site. Please refine or"
      assert html =~ "reset your search"

      assert element_exists?(html, ~s/a[phx-click="reset-filter-text"]#reset-filter-hint/)
      html = lv |> element(~s/a#reset-filter-hint/) |> render_click()

      refute html =~ "No goals found for this site. Please refine or"
    end

    test "Add Goal form view is rendered immediately, though hidden", %{conn: conn, site: site} do
      {:ok, _goals} = setup_goals(site)
      {_, html} = get_liveview(conn, site, with_html?: true)

      assert html =~ "Add Goal for #{site.domain}"

      assert element_exists?(
               html,
               ~s/#goals-form-modal form[phx-submit="save-goal"]/
             )
    end

    test "auto-configuring custom event goals", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:event, name: "Newsletter Signup"),
        build(:event, name: "Purchase")
      ])

      autoconfigure_button_selector = ~s/button[phx-click="autoconfigure"]/

      assert_suggested_event_name_count = fn html, number ->
        assert text_of_element(html, autoconfigure_button_selector) =~
                 "found #{number} custom events from the last 6 months that are not yet configured as goals"
      end

      {lv, html} = get_liveview(conn, site, with_html?: true)

      # At first, 3 event names are suggested
      assert_suggested_event_name_count.(html, 3)

      # Add one goal
      lv
      |> element("#goals-form-modal form")
      |> render_submit(%{goal: %{event_name: "Signup"}})

      html = render(lv)

      # Now two goals are suggested because one is already added
      assert_suggested_event_name_count.(html, 2)

      # Delete the goal
      goal = Plausible.Repo.get_by(Plausible.Goal, site_id: site.id, event_name: "Signup")
      html = lv |> element(~s/button#delete-goal-#{goal.id}/) |> render_click()

      # Suggested event name count should be 3 again
      assert_suggested_event_name_count.(html, 3)

      # Autoconfigure all custom event goals
      lv
      |> element(autoconfigure_button_selector)
      |> render_click()

      html = render(lv)

      # All possible goals exist - no suggestions anymore
      refute html =~ "from the last 6 months"
    end
  end

  defp setup_goals(site) do
    {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/go/to/blog/**"})
    {:ok, g2} = Plausible.Goals.create(site, %{"event_name" => "Register"})
    {:ok, g3} = Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})
    {:ok, [g1, g2, g3]}
  end

  defp get_liveview(conn, site, opts \\ []) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.GoalSettings)
    {:ok, lv, html} = live(conn, "/#{site.domain}/settings/goals")

    if Keyword.get(opts, :with_html?) do
      {lv, html}
    else
      lv
    end
  end

  defp type_into_search(lv, text) do
    lv
    |> element("form#filter-form")
    |> render_change(%{
      "_target" => ["filter-text"],
      "filter-text" => "#{text}"
    })
  end
end
