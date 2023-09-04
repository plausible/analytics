defmodule PlausibleWeb.Live.GoalSettingsTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "GET /:website/settings/goals" do
    setup [:create_user, :log_in, :create_site]

    test "lists goals for the site and renders links", %{conn: conn, site: site} do
      {:ok, [g1, g2, g3]} = setup_goals(site)
      conn = get(conn, "/#{site.domain}/settings/goals")

      resp = html_response(conn, 200)
      assert resp =~ "Define actions that you want your users to take"
      assert resp =~ "compose goals into funnels"
      assert resp =~ "/#{site.domain}/settings/funnels"
      assert element_exists?(resp, ~s|a[href="https://plausible.io/docs/goal-conversions"]|)

      assert resp =~ to_string(g1)
      assert resp =~ "Pageview"
      assert resp =~ to_string(g2)
      assert resp =~ "Custom Event"
      assert resp =~ to_string(g3)
      assert resp =~ "Revenue Goal: EUR"
    end

    test "lists goals with delete actions", %{conn: conn, site: site} do
      {:ok, goals} = setup_goals(site)
      conn = get(conn, "/#{site.domain}/settings/goals")
      resp = html_response(conn, 200)

      for g <- goals do
        assert element_exists?(
                 resp,
                 ~s/button[phx-click="delete-goal"][phx-value-goal-id=#{g.id}]#delete-goal-#{g.id}/
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
      assert element_exists?(resp, ~s/button[phx-click="add-goal"]/)
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

    test "clicking Add Goal button renders the form view", %{conn: conn, site: site} do
      {:ok, _goals} = setup_goals(site)
      lv = get_liveview(conn, site)
      html = lv |> element(~s/button[phx-click="add-goal"]/) |> render_click()

      assert html =~ "Add goal for #{site.domain}"

      assert element_exists?(
               html,
               ~s/div#goals-form form[phx-submit="save-goal"][phx-click-away="cancel-add-goal"]/
             )
    end
  end

  defp setup_goals(site) do
    {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/go/to/blog/**"})
    {:ok, g2} = Plausible.Goals.create(site, %{"event_name" => "Signup"})
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
