defmodule PlausibleWeb.Live.FunnelSettings.FormTest do
  use PlausibleWeb.ConnCase, async: true
  @moduletag :ee_only

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "integration - live rendering" do
    setup [:create_user, :log_in, :create_site]

    test "search reacts to the input, the user types in", %{conn: conn, site: site} do
      setup_goals(site, ["Hello World", "Plausible", "Another World"])
      lv = get_liveview(conn, site)

      doc = type_into_combo(lv, 1, "hello")

      assert text_of_element(doc, "#dropdown-step-1-option-1") == "Hello World"

      doc = type_into_combo(lv, 1, "plausible")

      assert text_of_element(doc, "#dropdown-step-1-option-1") == "Plausible"
    end

    test "selecting an option prefills input values", %{conn: conn, site: site} do
      {:ok, [_, _, g3]} = setup_goals(site, ["Hello World", "Plausible", "Another World"])
      lv = get_liveview(conn, site)

      doc = type_into_combo(lv, 1, "another")

      refute element_exists?(doc, ~s/input[type="hidden"][value="#{g3.id}"]/)
      refute element_exists?(doc, ~s/input[type="text"][value="Another World"]/)

      lv
      |> element("li#dropdown-step-1-option-1 a")
      |> render_click()

      assert lv
             |> element("#submit-step-1")
             |> render()
             |> element_exists?(~s/input[type="hidden"][value="#{g3.id}"]/)

      assert lv
             |> element("#step-1")
             |> render()
             |> element_exists?(~s/input[type="text"][value="Another World"]/)
    end

    test "selecting one option reduces suggestions in the other", %{conn: conn, site: site} do
      setup_goals(site, ["Hello World", "Plausible", "Another World"])
      lv = get_liveview(conn, site)

      type_into_combo(lv, 1, "another")

      lv
      |> element("li#dropdown-step-1-option-1 a")
      |> render_click()

      doc = type_into_combo(lv, 2, "another")

      refute text_of_element(doc, "ul#dropdown-step-1 li") =~ "Another World"
      refute text_of_element(doc, "ul#dropdown-step-2 li") =~ "Another World"
    end

    test "suggestions are limited on change", %{conn: conn, site: site} do
      setup_goals(site, for(i <- 1..20, do: "Goal #{i}"))
      lv = get_liveview(conn, site)

      doc =
        lv
        |> element("li#dropdown-step-1-option-1 a")
        |> render_click()

      assert element_exists?(doc, ~s/#li#dropdown-step-1-option-15/)
      refute element_exists?(doc, ~s/#li#dropdown-step-1-option-16/)
    end

    test "removing one option alters suggestions for other", %{conn: conn, site: site} do
      setup_goals(site, ["Hello World", "Plausible", "Another World"])

      lv = get_liveview(conn, site)

      lv |> element(~s/a[phx-click="add-step"]/) |> render_click()

      type_into_combo(lv, 2, "hello")

      lv
      |> element("li#dropdown-step-2-option-1 a")
      |> render_click()

      doc = type_into_combo(lv, 1, "hello")

      refute text_of_element(doc, "ul#dropdown-step-0 li") =~ "Hello World"

      lv |> element(~s/#remove-step-2/) |> render_click()

      doc = type_into_combo(lv, 1, "hello")

      assert text_of_element(doc, "ul#dropdown-step-1 li") =~ "Hello World"
    end
  end

  defp get_liveview(conn, site) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.FunnelSettings)
    {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/funnels")
    lv |> element(~s/button[phx-click="add-funnel"]/) |> render_click()
    assert form_view = find_live_child(lv, "funnels-form")
    form_view |> element("form") |> render_change(%{funnel: %{name: "My test funnel"}})
    form_view
  end

  defp setup_goals(site, goal_names) when is_list(goal_names) do
    goals =
      Enum.map(goal_names, fn goal_name ->
        {:ok, g} = Plausible.Goals.create(site, %{"event_name" => goal_name})
        g
      end)

    {:ok, goals}
  end

  defp type_into_combo(lv, idx, text) do
    lv
    |> element("input#step-#{idx}")
    |> render_change(%{
      "_target" => ["display-step-#{idx}"],
      "display-step-#{idx}" => "#{text}"
    })
  end
end
