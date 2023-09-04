defmodule PlausibleWeb.Live.FunnelSettingsTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "GET /:website/settings/funnels" do
    setup [:create_user, :log_in, :create_site]

    test "lists funnels for the site and renders help link", %{conn: conn, site: site} do
      {:ok, _} = setup_funnels(site)
      conn = get(conn, "/#{site.domain}/settings/funnels")

      resp = html_response(conn, 200)
      assert resp =~ "Compose goals into funnels"
      assert resp =~ "From blog to signup"
      assert resp =~ "From signup to blog"
      assert element_exists?(resp, "a[href=\"https://plausible.io/docs/funnel-analysis\"]")
    end

    test "lists funnels with delete actions", %{conn: conn, site: site} do
      {:ok, [f1_id, f2_id]} = setup_funnels(site)
      conn = get(conn, "/#{site.domain}/settings/funnels")

      resp = html_response(conn, 200)

      assert element_exists?(
               resp,
               ~s/button[phx-click="delete-funnel"][phx-value-funnel-id=#{f1_id}]#delete-funnel-#{f1_id}/
             )

      assert element_exists?(
               resp,
               ~s/button[phx-click="delete-funnel"][phx-value-funnel-id=#{f2_id}]#delete-funnel-#{f2_id}/
             )
    end

    test "if goals are present, Add Funnel button is rendered", %{conn: conn, site: site} do
      {:ok, _} = setup_funnels(site)
      conn = get(conn, "/#{site.domain}/settings/funnels")
      resp = conn |> html_response(200)
      assert element_exists?(resp, ~S/button[phx-click="add-funnel"]/)
    end

    test "if not enough goals are present, a hint to create goals is rendered", %{
      conn: conn,
      site: site
    } do
      {:ok, _} = Plausible.Goals.create(site, %{"page_path" => "/go/to/blog/**"})
      conn = get(conn, "/#{site.domain}/settings/funnels")

      doc = conn |> html_response(200)
      assert Floki.text(doc) =~ "You need to define at least two goals to create a funnel."

      add_goals_path = Routes.site_path(conn, :settings_goals, site.domain)
      assert element_exists?(doc, ~s/a[href="#{add_goals_path}"]/)
    end
  end

  describe "FunnelSettings live view" do
    setup [:create_user, :log_in, :create_site]

    test "allows to delete funnels", %{conn: conn, site: site} do
      {:ok, [f1_id, _f2_id]} = setup_funnels(site)

      {lv, html} = get_liveview(conn, site, with_html?: true)

      assert html =~ "From blog to signup"
      assert html =~ "From signup to blog"

      html = lv |> element(~s/button#delete-funnel-#{f1_id}/) |> render_click()

      refute html =~ "From blog to signup"
      assert html =~ "From signup to blog"

      html = get(conn, "/#{site.domain}/settings/funnels") |> html_response(200)

      refute html =~ "From blog to signup"
      assert html =~ "From signup to blog"
    end

    test "renders the funnel form on clicking 'Add Funnel' button", %{conn: conn, site: site} do
      setup_goals(site)
      lv = get_liveview(conn, site)
      doc = render_click(lv, "add-funnel")

      assert element_exists?(doc, ~s/form[phx-change="validate"][phx-submit="save"]/)
      assert element_exists?(doc, ~s/form input[type="text"][name="funnel[name]"]/)

      assert element_exists?(
               doc,
               ~s/input[type="hidden"][name="funnel[steps][][goal_id]"]#submit-step-1/
             )

      step_setup_controls = [
        ~s/input[type="hidden"][name="funnel[steps][][goal_id]"]#submit-step-1/,
        ~s/input[type="hidden"][name="funnel[steps][][goal_id]"]#submit-step-2/,
        ~s/input[type="text"][name="display-step-1"]#step-1/,
        ~s/input[type="text"][name="display-step-2"]#step-2/,
        ~s/a[phx-click="add-step"]/
      ]

      Enum.each(step_setup_controls, &assert(element_exists?(doc, &1)))
    end

    test "clicking 'Add another step' adds a pair of inputs and renders remove step buttons", %{
      conn: conn,
      site: site
    } do
      setup_goals(site)
      lv = get_liveview(conn, site)

      lv |> element(~s/button[phx-click="add-funnel"]/) |> render_click()

      assert lv = find_live_child(lv, "funnels-form")
      lv |> element("form") |> render_change(%{funnel: %{name: "My test funnel"}})
      doc = lv |> element(~s/a[phx-click="add-step"]/) |> render_click()

      assert element_exists?(
               doc,
               ~s/input[type="hidden"][name="funnel[steps][][goal_id]"]#submit-step-3/
             )

      assert element_exists?(doc, ~s/input[type="text"][name="display-step-1"]#step-1/)

      assert element_exists?(
               doc,
               ~s/svg#remove-step-1[phx-click="remove-step"][phx-value-step-idx="1"]/
             )

      assert element_exists?(
               doc,
               ~s/svg#remove-step-2[phx-click="remove-step"][phx-value-step-idx="2"]/
             )

      assert element_exists?(
               doc,
               ~s/svg#remove-step-3[phx-click="remove-step"][phx-value-step-idx="3"]/
             )
    end

    test "clicking the 'remove step' button removes a step", %{site: site, conn: conn} do
      setup_goals(site)
      lv = get_liveview(conn, site)

      lv |> element(~s/button[phx-click="add-funnel"]/) |> render_click()
      assert lv = find_live_child(lv, "funnels-form")
      lv |> element("form") |> render_change(%{funnel: %{name: "My test funnel"}})
      lv |> element(~s/a[phx-click="add-step"]/) |> render_click()

      doc = lv |> element(~s/#remove-step-2/) |> render_click()

      assert element_exists?(doc, ~s/input#step-1/)
      assert element_exists?(doc, ~s/input#step-3/)
      refute element_exists?(doc, ~s/input#step-2/)
    end

    test "save button becomes active once at least two steps are selected", %{
      conn: conn,
      site: site
    } do
      setup_goals(site)
      lv = get_liveview(conn, site)
      lv |> element(~s/button[phx-click="add-funnel"]/) |> render_click()

      assert lv = find_live_child(lv, "funnels-form")

      lv
      |> element("li#dropdown-step-1-option-1 a")
      |> render_click()

      doc =
        lv
        |> element("li#dropdown-step-2-option-1 a")
        |> render_click()

      save_inactive = ~s/form button#save.cursor-not-allowed/
      save_active = ~s/form button#save[type="submit"]/

      refute element_exists?(doc, save_active)
      assert element_exists?(doc, save_inactive)

      doc =
        lv
        |> element("form")
        |> render_change(%{
          funnel: %{
            name: "My test funnel",
            steps: [
              %{goal_id: 1},
              %{goal_id: 2}
            ]
          }
        })

      assert element_exists?(doc, save_active)
      refute element_exists?(doc, save_inactive)
    end

    test "funnel gets evaluated on every select, assuming a second has passed between selections",
         %{
           conn: conn,
           site: site
         } do
      setup_goals(site)
      lv = get_liveview(conn, site)
      lv |> element(~s/button[phx-click="add-funnel"]/) |> render_click()

      assert lv = find_live_child(lv, "funnels-form")

      lv |> element("li#dropdown-step-1-option-1 a") |> render_click()

      :timer.sleep(1001)

      lv |> element("li#dropdown-step-2-option-1 a") |> render_click()

      doc = lv |> element("#step-eval-0") |> render()
      assert text_of_element(doc, ~s/#step-eval-0/) =~ "Entering Visitors: 0"

      doc = lv |> element("#step-eval-1") |> render()
      assert text_of_element(doc, ~s/#step-eval-1/) =~ "Dropoff: 0%"

      doc = lv |> element("#funnel-eval") |> render()
      assert text_of_element(doc, ~s/#funnel-eval/) =~ "Last month conversion rate: 0%"
    end

    test "cancel buttons renders the funnel list", %{
      conn: conn,
      site: site
    } do
      setup_goals(site)
      lv = get_liveview(conn, site)
      doc = lv |> element(~s/button[phx-click="add-funnel"]/) |> render_click()

      cancel_button = ~s/button#cancel[phx-click="cancel-add-funnel"]/

      assert element_exists?(doc, cancel_button)

      doc =
        lv
        |> element(cancel_button)
        |> render_click()

      assert doc =~ "No funnels configured for this site yet"
      assert element_exists?(doc, ~S/button[phx-click="add-funnel"]/)
    end
  end

  defp setup_funnels(site) do
    {:ok, [g1, g2]} = setup_goals(site)

    {:ok, f1} =
      Plausible.Funnels.create(
        site,
        "From blog to signup",
        [%{"goal_id" => g1.id}, %{"goal_id" => g2.id}]
      )

    {:ok, f2} =
      Plausible.Funnels.create(
        site,
        "From signup to blog",
        [%{"goal_id" => g2.id}, %{"goal_id" => g1.id}]
      )

    {:ok, [f1.id, f2.id]}
  end

  defp setup_goals(site) do
    {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/go/to/blog/**"})
    {:ok, g2} = Plausible.Goals.create(site, %{"event_name" => "Signup"})
    {:ok, [g1, g2]}
  end

  defp get_liveview(conn, site, opts \\ []) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.FunnelSettings)
    {:ok, lv, html} = live(conn, "/#{site.domain}/settings/funnels")

    if Keyword.get(opts, :with_html?) do
      {lv, html}
    else
      lv
    end
  end
end
