defmodule PlausibleWeb.Live.GoalSettings.PropertyPairsTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias PlausibleWeb.Live.GoalSettings.PropertyPairs

  describe "static rendering" do
    setup [:create_user, :create_site]

    test "renders empty property pair by default", %{site: site} do
      doc = render_pairs_component(site)

      assert element_exists?(doc, ~s/div[data-test-id="custom-property-pairs"]/)
      assert element_exists?(doc, ~s/div[id^="property_pair_"]/)
      assert element_exists?(doc, ~s/input[name="goal[custom_props][keys][]"]/)
      assert element_exists?(doc, ~s/input[name="goal[custom_props][values][]"]/)
    end

    test "renders 'Add another property' link when slots are below max", %{site: site} do
      doc = render_pairs_component(site)
      assert text_of_element(doc, ~s/a[phx-click="add-slot"]/) == "+ Add another property"
    end

    test "does not render 'Add another property' link when slots are at max", %{site: site} do
      {:ok, goal} =
        Plausible.Goals.create(site, %{
          "event_name" => "TestEvent",
          "custom_props" => %{"prop1" => "val1", "prop2" => "val2", "prop3" => "val3"}
        })

      doc = render_pairs_component(site, goal: goal)

      refute element_exists?(doc, ~s/a[phx-click="add-slot"]/)
      refute doc =~ "+ Add another property"
    end

    test "does not show remove button when only one slot exists", %{site: site} do
      doc = render_pairs_component(site)
      refute element_exists?(doc, ~s/div[data-test-id^="remove-property-"]/)
    end

    test "shows remove button when multiple slots exist", %{site: site} do
      {:ok, goal} =
        Plausible.Goals.create(site, %{
          "event_name" => "TestEvent",
          "custom_props" => %{"prop1" => "val1", "prop2" => "val2"}
        })

      doc = render_pairs_component(site, goal: goal)

      assert element_exists?(doc, ~s/div[data-test-id^="remove-property-"]/)
    end

    test "renders property pairs for goal with existing custom props", %{site: site} do
      {:ok, goal} =
        Plausible.Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"product" => "Shirt", "color" => "Blue"}
        })

      doc = render_pairs_component(site, goal: goal)

      assert element_exists?(doc, ~s/input[value="product"]/)
      assert element_exists?(doc, ~s/input[value="Shirt"]/)
      assert element_exists?(doc, ~s/input[value="color"]/)
      assert element_exists?(doc, ~s/input[value="Blue"]/)
    end

    test "pre-populates property pairs when editing goal with custom props", %{site: site} do
      {:ok, goal} =
        Plausible.Goals.create(site, %{
          "event_name" => "Signup",
          "custom_props" => %{"tier" => "Premium"}
        })

      doc = render_pairs_component(site, goal: goal)

      assert element_exists?(doc, ~s/input[value="tier"]/)
      assert element_exists?(doc, ~s/input[value="Premium"]/)
    end
  end

  describe "integration with live view" do
    setup [:create_user, :create_site]

    defmodule TestLiveView do
      use Phoenix.LiveView

      def render(assigns) do
        ~H"""
        <div>
          <.live_component
            id="test-property-pairs"
            module={PlausibleWeb.Live.GoalSettings.PropertyPairs}
            site={@site}
            goal={@goal}
          />
        </div>
        """
      end

      def mount(_params, session, socket) do
        {:ok, assign(socket, site: session["site"], goal: session["goal"])}
      end
    end

    test "adds new slot when 'Add another property' is clicked", %{conn: conn, site: site} do
      {:ok, lv, html} =
        live_isolated(conn, TestLiveView, session: %{"site" => site, "goal" => nil})

      assert elem_count(html, ~s/div[id^="property_pair_"]/) == 1

      lv
      |> element("a[phx-click='add-slot']")
      |> render_click()

      html = render(lv)

      assert elem_count(html, ~s/div[id^="property_pair_"]/) == 2
    end

    test "removes slot when remove button is clicked", %{conn: conn, site: site} do
      {:ok, goal} =
        Plausible.Goals.create(site, %{
          "event_name" => "TestEvent",
          "custom_props" => %{"prop1" => "val1", "prop2" => "val2"}
        })

      {:ok, lv, html} =
        live_isolated(conn, TestLiveView, session: %{"site" => site, "goal" => goal})

      assert elem_count(html, ~s/div[id^="property_pair_"]/) == 2

      first_remove_button =
        html
        |> find(~s/div[data-test-id^="remove-property-"] [phx-click="remove-slot"]/)
        |> Enum.at(0)
        |> text_of_attr("id")

      lv
      |> element("##{first_remove_button}")
      |> render_click()

      html = render(lv)

      assert elem_count(html, ~s/div[id^="property_pair_"]/) == 1
    end

    test "does not add more slots when at max capacity", %{conn: conn, site: site} do
      {:ok, goal} =
        Plausible.Goals.create(site, %{
          "event_name" => "TestEvent",
          "custom_props" => %{"prop1" => "val1", "prop2" => "val2", "prop3" => "val3"}
        })

      {:ok, _lv, html} =
        live_isolated(conn, TestLiveView, session: %{"site" => site, "goal" => goal})

      assert elem_count(html, ~s/div[id^="property_pair_"]/) == 3
      assert elem_count(html, ~s/[phx-click="remove-slot"]/) == 3
      refute element_exists?(html, ~s/a[phx-click="add-slot"]/)
    end
  end

  defp render_pairs_component(site, extra_opts \\ []) do
    opts = Keyword.merge([id: "test-pairs", site: site], extra_opts)
    render_component(PropertyPairs, opts)
  end
end
