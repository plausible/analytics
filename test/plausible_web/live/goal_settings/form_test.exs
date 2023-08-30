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
      assert pageview_tab =~ "Page path"

      event_tab = lv |> element(~s/a#event-tab/) |> render_click()
      assert event_tab =~ "Event name"
    end

    test "escape closes the form", %{conn: conn, site: site} do
      {parent, lv} = get_liveview(conn, site, with_parent?: true)
      html = render(parent)
      assert html =~ "Goal trigger"
      render_keydown(lv, "cancel-add-goal")
      html = render(parent)
      refute html =~ "Goal trigger"
    end
  end

  describe "Goal submission" do
    setup [:create_user, :log_in, :create_site]

    test "renders form fields", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = render(lv)

      [event_name, currency_display, currency_submit] = find(html, "input")

      assert name_of(event_name) == "goal[event_name]"
      assert name_of(currency_display) == "display-currency_input"
      assert name_of(currency_submit) == "goal[currency]"

      html = lv |> element(~s/a#pageview-tab/) |> render_click()

      [page_path_display, page_path] = find(html, "input")
      assert name_of(page_path_display) == "display-page_path_input"
      assert name_of(page_path) == "goal[page_path]"
    end

    test "renders error on empty submission", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = lv |> element("form") |> render_submit()
      assert html =~ "this field is required and cannot be blank"

      pageview_tab = lv |> element(~s/a#pageview-tab/) |> render_click()
      assert pageview_tab =~ "this field is required and must start with a /"
    end

    test "creates a custom event", %{conn: conn, site: site} do
      {parent, lv} = get_liveview(conn, site, with_parent?: true)
      refute render(parent) =~ "Foo"
      lv |> element("form") |> render_submit(%{goal: %{event_name: "Foo"}})
      parent_html = render(parent)
      assert parent_html =~ "Foo"
      assert parent_html =~ "Custom Event"
    end

    test "creates a revenue goal", %{conn: conn, site: site} do
      {parent, lv} = get_liveview(conn, site, with_parent?: true)
      refute render(parent) =~ "Foo"
      lv |> element("form") |> render_submit(%{goal: %{event_name: "Foo", currency: "EUR"}})
      parent_html = render(parent)
      assert parent_html =~ "Foo"
      assert parent_html =~ "Revenue Goal: EUR"
    end

    test "creates a pageview goal", %{conn: conn, site: site} do
      {parent, lv} = get_liveview(conn, site, with_parent?: true)
      refute render(parent) =~ "Foo"
      lv |> element("form") |> render_submit(%{goal: %{page_path: "/page/**"}})
      parent_html = render(parent)
      assert parent_html =~ "Visit /page/**"
      assert parent_html =~ "Pageview"
    end
  end

  describe "Combos integration" do
    setup [:create_user, :log_in, :create_site]

    test "currency combo works", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)

      # Account for asynchronous updates. Here, the options, while static,
      # are still a sizeable payload that we can defer before the user manages
      # to click "this is revenue goal" switch.
      # There's also throttling applied to the ComboBox.
      :timer.sleep(200)
      type_into_combo(lv, "currency_input", "Polish")
      :timer.sleep(200)
      html = render(lv)

      assert element_exists?(html, ~s/a[phx-value-display-value="PLN - Polish Zloty"]/)
      refute element_exists?(html, ~s/a[phx-value-display-value="EUR - Euro"]/)

      type_into_combo(lv, "currency_input", "Euro")
      :timer.sleep(200)
      html = render(lv)

      refute element_exists?(html, ~s/a[phx-value-display-value="PLN - Polish Zloty"]/)
      assert element_exists?(html, ~s/a[phx-value-display-value="EUR - Euro"]/)
    end

    test "pageview combo works", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      lv |> element(~s/a#pageview-tab/) |> render_click()

      html = type_into_combo(lv, "page_path_input", "/hello")

      assert html =~ "Create &quot;/hello&quot;"
    end

    test "pageview combo uses filter suggestions", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/go/to/page/1"),
        build(:pageview, pathname: "/go/home")
      ])

      lv = get_liveview(conn, site)
      lv |> element(~s/a#pageview-tab/) |> render_click()

      type_into_combo(lv, "page_path_input", "/go/to/p")

      # Account some large-ish margin for Clickhouse latency when providing suggestions asynchronously
      # Might be too much, but also not enough on sluggish CI
      :timer.sleep(350)
      html = render(lv)
      assert html =~ "Create &quot;/go/to/p&quot;"
      assert html =~ "/go/to/page/1"
      refute html =~ "/go/home"

      type_into_combo(lv, "page_path_input", "/go/h")
      :timer.sleep(350)
      html = render(lv)
      assert html =~ "/go/home"
      refute html =~ "/go/to/page/1"
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

  defp get_liveview(conn, site, opts \\ []) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.GoalSettings)
    {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/goals")
    lv |> element(~s/button[phx-click="add-goal"]/) |> render_click()
    assert form_view = find_live_child(lv, "goals-form")

    if opts[:with_parent?] do
      {lv, form_view}
    else
      form_view
    end
  end
end
