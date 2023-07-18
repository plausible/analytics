defmodule PlausibleWeb.Live.Components.ComboBoxTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias PlausibleWeb.Live.Components.ComboBox

  @ul "ul#dropdown-test-component[x-show=isOpen][x-ref=suggestions]"

  describe "static rendering" do
    test "renders suggestions" do
      assert doc = render_sample_component(new_options(10))

      assert element_exists?(
               doc,
               ~s/input#test-component[name="display-test-component"][phx-change="search"]/
             )

      assert element_exists?(doc, @ul)

      for i <- 1..10 do
        assert element_exists?(doc, suggestion_li(i))
      end
    end

    test "renders up to 15 suggestions by default" do
      assert doc = render_sample_component(new_options(20))

      assert element_exists?(doc, suggestion_li(14))
      assert element_exists?(doc, suggestion_li(15))

      refute element_exists?(doc, suggestion_li(16))
      refute element_exists?(doc, suggestion_li(17))

      assert Floki.text(doc) =~ "Max results reached"
    end

    test "Alpine.js: renders attrs focusing suggestion elements" do
      assert doc = render_sample_component(new_options(10))
      li1 = doc |> find(suggestion_li(1)) |> List.first()
      li2 = doc |> find(suggestion_li(2)) |> List.first()

      assert text_of_attr(li1, "@mouseenter") == "setFocus(0)"
      assert text_of_attr(li2, "@mouseenter") == "setFocus(1)"

      assert text_of_attr(li1, "x-bind:class") =~ "focus === 0"
      assert text_of_attr(li2, "x-bind:class") =~ "focus === 1"
    end

    test "Alpine.js: component refers to window.suggestionsDropdown" do
      assert new_options(2)
             |> render_sample_component()
             |> find("div#input-picker-main-test-component")
             |> text_of_attr("x-data") =~ "window.suggestionsDropdown('test-component')"
    end

    test "Alpine.js: component sets up keyboard navigation" do
      main =
        new_options(2)
        |> render_sample_component()
        |> find("div#input-picker-main-test-component")

      assert text_of_attr(main, "x-on:keydown.arrow-up") == "focusPrev"
      assert text_of_attr(main, "x-on:keydown.arrow-down") == "focusNext"
      assert text_of_attr(main, "x-on:keydown.enter") == "select()"
    end

    test "Alpine.js: component sets up close on click-away" do
      assert new_options(2)
             |> render_sample_component()
             |> find("div#input-picker-main-test-component div div")
             |> text_of_attr("@click.away") == "close"
    end

    test "Alpine.js: component sets up open on focusing the display input" do
      assert new_options(2)
             |> render_sample_component()
             |> find("input#test-component")
             |> text_of_attr("x-on:focus") == "open"
    end

    test "Alpine.js: dropdown is annotated and shows when isOpen is true" do
      dropdown =
        new_options(2)
        |> render_sample_component()
        |> find("#dropdown-test-component")

      assert text_of_attr(dropdown, "x-show") == "isOpen"
      assert text_of_attr(dropdown, "x-ref") == "suggestions"
    end

    test "Dropdown shows a notice when no suggestions exist" do
      doc = render_sample_component([])

      assert text_of_element(doc, "#dropdown-test-component") ==
               "No matches found. Try searching for something different."
    end
  end

  defp render_sample_component(options) do
    render_component(ComboBox,
      options: options,
      submit_name: "test-submit-name",
      id: "test-component",
      suggest_mod: ComboBox.StaticSearch
    )
  end

  defp new_options(n) do
    Enum.map(1..n, &{&1, "TestOption #{&1}"})
  end

  defp suggestion_li(idx) do
    ~s/#{@ul} li#dropdown-test-component-option-#{idx - 1}/
  end
end
