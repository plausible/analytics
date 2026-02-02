defmodule PlausibleWeb.Live.GoalSettings.PropertyPairInputTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias PlausibleWeb.Live.GoalSettings.PropertyPairInput

  describe "static rendering" do
    setup [:create_user, :create_site]

    test "renders both property name and value comboboxes", %{site: site} do
      doc = render_pair_component(site, "test-pair")

      assert element_exists?(
               doc,
               ~s/input#test-pair_key[name="display-test-pair_key"][phx-change="search"]/
             )

      assert element_exists?(
               doc,
               ~s/input#test-pair_value[name="display-test-pair_value"][phx-change="search"]/
             )
    end

    test "property value combobox shows 'Select property first' when no property selected", %{
      site: site
    } do
      doc = render_pair_component(site, "test-pair")

      assert element_exists?(
               doc,
               ~s/input#test-pair_value[placeholder="Select property first"]/
             )
    end

    test "property value combobox shows 'Select value' when property is selected", %{site: site} do
      doc = render_pair_component(site, "test-pair", selected_property: "product")

      assert element_exists?(
               doc,
               ~s/input#test-pair_value[placeholder="Select value"]/
             )
    end

    test "both comboboxes have correct submit names", %{site: site} do
      doc = render_pair_component(site, "test-pair")

      assert element_exists?(
               doc,
               ~s/input[type="hidden"][name="goal[custom_props][keys][]"]/
             )

      assert element_exists?(
               doc,
               ~s/input[type="hidden"][name="goal[custom_props][values][]"]/
             )
    end

    test "renders wrapper div with correct ID", %{site: site} do
      doc = render_pair_component(site, "my-custom-id")

      assert element_exists?(doc, ~s/div#my-custom-id/)
    end

    test "both comboboxes are marked as creatable", %{site: site} do
      doc = render_pair_component(site, "test-pair")

      assert text_of_element(doc, "#dropdown-test-pair_key") =~ "Create an item by typing."
      assert text_of_element(doc, "#dropdown-test-pair_value") =~ "Create an item by typing."
    end

    test "pre-populates property key when initial_prop_key is provided", %{site: site} do
      doc = render_pair_component(site, "test-pair", initial_prop_key: "product")

      assert element_exists?(
               doc,
               ~s/input#test-pair_key[name="display-test-pair_key"][value="product"]/
             )
    end

    test "pre-populates property value when initial_prop_value is provided", %{site: site} do
      doc = render_pair_component(site, "test-pair", initial_prop_value: "Shirt")

      assert element_exists?(
               doc,
               ~s/input#test-pair_value[name="display-test-pair_value"][value="Shirt"]/
             )
    end

    test "pre-populates both property key and value when both are provided", %{site: site} do
      doc =
        render_pair_component(site, "test-pair",
          initial_prop_key: "product",
          initial_prop_value: "Shirt"
        )

      assert element_exists?(
               doc,
               ~s/input#test-pair_key[name="display-test-pair_key"][value="product"]/
             )

      assert element_exists?(
               doc,
               ~s/input#test-pair_value[name="display-test-pair_value"][value="Shirt"]/
             )
    end

    test "value combobox shows 'Select value' when property is pre-populated", %{site: site} do
      doc = render_pair_component(site, "test-pair", initial_prop_key: "product")

      assert element_exists?(
               doc,
               ~s/input#test-pair_value[placeholder="Select value"]/
             )
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
            id="test-property-pair"
            module={PlausibleWeb.Live.GoalSettings.PropertyPairInput}
            site={@site}
          />
        </div>
        """
      end

      def mount(_params, %{"site" => site}, socket) do
        {:ok, assign(socket, site: site)}
      end
    end

    test "selecting property value based on name selection", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["product"],
          "meta.value": ["Shirt"]
        )
      ])

      {:ok, lv, html} = live_isolated(conn, TestLiveView, session: %{"site" => site})

      assert html =~ "Select property first"

      html = type_into_combo(lv, "test-property-pair_key", "zzz")
      refute element_exists?(html, "li#dropdown-test-property-pair_key-option-1 a")

      type_into_combo(lv, "test-property-pair_key", "duct")

      lv
      |> element("li#dropdown-test-property-pair_key-option-1 a")
      |> render_click()

      html = render(lv)

      refute html =~ "Select property first"
      assert html =~ "Select value"

      html = type_into_combo(lv, "test-property-pair_value", "zzz")
      refute html =~ "Shirt"

      html = type_into_combo(lv, "test-property-pair_value", "irt")
      assert html =~ "Shirt"

      lv
      |> element("li#dropdown-test-property-pair_value-option-1 a")
      |> render_click()
    end
  end

  defp render_pair_component(site, id, extra_opts \\ []) do
    opts = Keyword.merge([id: id, site: site], extra_opts)
    render_component(PropertyPairInput, opts)
  end

  defp type_into_combo(lv, id, text) do
    lv
    |> element("input##{id}")
    |> render_change(%{
      "_target" => ["display-#{id}"],
      "display-#{id}" => "#{text}"
    })
  end
end
