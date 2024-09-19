defmodule PlausibleWeb.Live.FunnelSettingsTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    describe "GET /:domain/settings/funnels" do
      setup [:create_user, :log_in, :create_site]

      test "lists funnels for the site and renders help link", %{conn: conn, site: site} do
        {:ok, _} = setup_funnels(site)
        conn = get(conn, "/#{site.domain}/settings/funnels")

        resp = html_response(conn, 200)
        assert resp =~ "Compose Goals into Funnels"
        assert resp =~ "From blog to signup"
        assert resp =~ "From signup to blog"
        assert element_exists?(resp, "a[href=\"https://plausible.io/docs/funnel-analysis\"]")
      end

      test "search funnels input is rendered", %{conn: conn, site: site} do
        setup_goals(site)
        conn = get(conn, "/#{site.domain}/settings/funnels")
        resp = html_response(conn, 200)
        assert element_exists?(resp, ~s/input[type="text"]#filter-text/)
        assert element_exists?(resp, ~s/form[phx-change="filter"]#filter-form/)
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

      test "if not enough goals are present, renders a hint to create goals + no search", %{
        conn: conn,
        site: site
      } do
        {:ok, _} = Plausible.Goals.create(site, %{"page_path" => "/go/to/blog/**"})
        conn = get(conn, "/#{site.domain}/settings/funnels")

        doc = conn |> html_response(200)
        assert Floki.text(doc) =~ "You need to define at least two goals to create a funnel."

        add_goals_path = Routes.site_path(conn, :settings_goals, site.domain)
        assert element_exists?(doc, ~s/a[href="#{add_goals_path}"]/)

        refute element_exists?(doc, ~s/input[type="text"]#filter-text/)
        refute element_exists?(doc, ~s/form[phx-change="filter"]#filter-form/)
      end
    end

    describe "FunnelSettings live view" do
      setup [:create_user, :log_in, :create_site]

      test "allows list filtering / search", %{conn: conn, site: site} do
        {:ok, _} = setup_funnels(site, ["Funnel One", "Search Me"])
        {lv, html} = get_liveview(conn, site, with_html?: true)

        assert html =~ "Funnel One"
        assert html =~ "Search Me"

        html = type_into_search(lv, "search")

        refute html =~ "Funnel One"
        assert html =~ "Search Me"
      end

      test "allows resetting filter text via backspace icon", %{conn: conn, site: site} do
        {:ok, _} = setup_funnels(site, ["Funnel One", "Another"])
        {lv, html} = get_liveview(conn, site, with_html?: true)

        refute element_exists?(html, ~s/svg[phx-click="reset-filter-text"]#reset-filter/)

        html = type_into_search(lv, "one")
        refute html =~ "Another"

        assert element_exists?(html, ~s/svg[phx-click="reset-filter-text"]#reset-filter/)

        html = lv |> element(~s/svg#reset-filter/) |> render_click()

        assert html =~ "Funnel One"
        assert html =~ "Another"
      end

      test "allows resetting filter text via no match link", %{conn: conn, site: site} do
        {:ok, _} = setup_funnels(site)
        lv = get_liveview(conn, site)
        html = type_into_search(lv, "Definitely this is not going to render any matches")

        assert html =~ "No funnels found for this site. Please refine or"
        assert html =~ "reset your search"

        assert element_exists?(html, ~s/a[phx-click="reset-filter-text"]#reset-filter-hint/)
        html = lv |> element(~s/a#reset-filter-hint/) |> render_click()

        refute html =~ "No funnels found for this site. Please refine or"
      end

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

        assert element_exists?(
                 doc,
                 ~s/form[phx-change="validate"][phx-submit="save"][phx-click-away="cancel-add-funnel"]/
               )

        assert element_exists?(doc, ~s/form input[type="text"][name="funnel[name]"]/)

        assert element_exists?(
                 doc,
                 ~s/input[type="hidden"][name="funnel[steps][1][goal_id]"]#submit-step-1/
               )

        step_setup_controls = [
          ~s/input[type="hidden"][name="funnel[steps][1][goal_id]"]#submit-step-1/,
          ~s/input[type="hidden"][name="funnel[steps][2][goal_id]"]#submit-step-2/,
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
                 ~s/input[type="hidden"][name="funnel[steps][3][goal_id]"]#submit-step-3/
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

        assert element_exists?(doc, ~s/form button#save:disabled/)

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

        assert element_exists?(doc, ~s/form button#save/)
        refute element_exists?(doc, ~s/form button#save:disabled/)
      end

      test "save button saves a new funnel", %{
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

        lv
        |> element("li#dropdown-step-2-option-1 a")
        |> render_click()

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

        lv
        |> element(~s/form/)
        |> render_submit()

        assert %Plausible.Funnel{steps: [_, _]} = Plausible.Funnels.get(site, "My test funnel")
      end

      test "editing a funnel pre-renders it", %{
        conn: conn,
        site: site
      } do
        {:ok, [f1_id, _]} = setup_funnels(site)
        lv = get_liveview(conn, site)

        lv
        |> element(~s/a[phx-click="edit-funnel"][phx-value-funnel-id=#{f1_id}]/)
        |> render_click()

        assert lv = find_live_child(lv, "funnels-form")

        assert lv |> element("#step-1") |> render() |> text_of_attr("value") ==
                 "Visit /go/to/blog/**"

        assert lv |> element("#step-2") |> render() |> text_of_attr("value") == "Signup"
      end

      test "clicking save after editing the funnel, updates it", %{
        conn: conn,
        site: site
      } do
        {:ok, [f1_id, _]} = setup_funnels(site)
        {:ok, %{id: goal_id}} = Plausible.Goals.create(site, %{"page_path" => "/"})

        lv = get_liveview(conn, site)

        lv
        |> element(~s/a[phx-click="edit-funnel"][phx-value-funnel-id=#{f1_id}]/)
        |> render_click()

        assert lv = find_live_child(lv, "funnels-form")

        lv
        |> element("li#dropdown-step-2-option-1 a")
        |> render_click()

        lv
        |> element("form")
        |> render_change(%{
          funnel: %{
            name: "Updated funnel",
            steps: [
              %{goal_id: 1},
              %{goal_id: goal_id}
            ]
          }
        })

        lv
        |> element(~s/form/)
        |> render_submit()

        assert %Plausible.Funnel{steps: [_, %Plausible.Funnel.Step{goal_id: ^goal_id}]} =
                 Plausible.Funnels.get(site, "Updated funnel")
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

        lv |> element("li#dropdown-step-2-option-1 a") |> render_click()

        doc = lv |> element("#step-eval-0") |> render()
        assert text_of_element(doc, ~s/#step-eval-0/) =~ "Entering Visitors: 0"

        doc = lv |> element("#step-eval-1") |> render()
        assert text_of_element(doc, ~s/#step-eval-1/) =~ "Dropoff: 0%"

        doc = lv |> element("#funnel-eval") |> render()
        assert text_of_element(doc, ~s/#funnel-eval/) =~ "Last month conversion rate: 0%"
      end
    end

    defp setup_funnels(site, names \\ []) do
      {:ok, [g1, g2]} = setup_goals(site)

      {:ok, f1} =
        Plausible.Funnels.create(
          site,
          Enum.at(names, 0) || "From blog to signup",
          [%{"goal_id" => g1.id}, %{"goal_id" => g2.id}]
        )

      {:ok, f2} =
        Plausible.Funnels.create(
          site,
          Enum.at(names, 1) || "From signup to blog",
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

    defp type_into_search(lv, text) do
      lv
      |> element("form#filter-form")
      |> render_change(%{
        "_target" => ["filter-text"],
        "filter-text" => "#{text}"
      })
    end
  end
end
