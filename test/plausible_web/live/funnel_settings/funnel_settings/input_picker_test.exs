defmodule PlausibleWeb.Live.FunnelSettings.InputPickerTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias PlausibleWeb.Live.FunnelSettings.InputPicker

  @ul "ul#dropdown-test-component[x-show=isOpen][x-ref=suggestions]"

  defp suggestion_li(idx) do
    ~s/#{@ul} li#dropdown-test-component-option-#{idx - 1}/
  end

  describe "static" do
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
    end

    test "search suggestions: favours exact match" do
      options = fake_options(["yellow", "hello", "cruel hello world"])

      assert [{_, "hello"}, {_, "cruel hello world"}, {_, "yellow"}] =
               InputPicker.suggest("hello", options)
    end

    test "search suggestions: skips entries shorter than input" do
      options = fake_options(["yellow", "hello", "cruel hello world"])

      assert [{_, "cruel hello world"}] = InputPicker.suggest("cruel hello", options)
    end

    test "search suggesions: favours similiarity" do
      options = fake_options(["melon", "hello", "yellow"])
      assert [{_, "hello"}, {_, "yellow"}, {_, "melon"}] = InputPicker.suggest("hell", options)
    end

    test "search suggesions: allows fuzzy matching" do
      options = fake_options(["/url/0xC0FFEE", "/url/0xDEADBEEF", "/url/other"])

      assert [{_, "/url/0xC0FFEE"}, {_, "/url/0xDEADBEEF"}, {_, "/url/other"}] =
               InputPicker.suggest("0x FF", options)
    end
  end

  @step1_input "input#step-1"
  describe "integration - live rendering" do
    setup [:create_user, :log_in, :create_site]

    test "search reacts to the input, the user types in", %{conn: conn, site: site} do
      setup_goals(site, ["Hello World", "Plausible", "Another World"])
      lv = get_liveview(conn, site)

      doc =
        lv
        |> element(@step1_input)
        |> render_change(%{
          "_target" => ["display-step-1"],
          "display-step-1" => "hello"
        })

      assert text_of_element(doc, "#dropdown-step-1-option-0") == "Hello World"

      doc =
        lv
        |> element(@step1_input)
        |> render_change(%{
          "_target" => ["display-step-1"],
          "display-step-1" => "plausible"
        })

      assert text_of_element(doc, "#dropdown-step-1-option-0") == "Plausible"
    end

    test "selecting an option prefills submit value", %{conn: conn, site: site} do
      {:ok, [_, _, g3]} = setup_goals(site, ["Hello World", "Plausible", "Another World"])
      lv = get_liveview(conn, site)

      doc =
        lv
        |> element(@step1_input)
        |> render_change(%{
          "_target" => ["display-step-1"],
          "display-step-1" => "another"
        })

      refute element_exists?(doc, ~s/input[type="hidden"][value="#{g3.id}"]/)

      lv
      |> element("li#dropdown-step-1-option-0 a")
      |> render_click()

      rendered =
        lv
        |> element("#submit-step-1")
        |> render()

      assert element_exists?(rendered, ~s/input[type="hidden"][value="#{g3.id}"]/)
    end
  end

  defp render_sample_component(options) do
    render_component(InputPicker,
      options: options,
      submit_name: "test-submit-name",
      id: "test-component"
    )
  end

  defp new_options(n) do
    Enum.map(1..n, &{&1, "TestOption #{&1}"})
  end

  defp get_liveview(conn, site) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.FunnelSettings)
    {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/funnels")
    lv |> element(~s/button[phx-click="add-funnel"]/) |> render_click()
    lv |> element("form") |> render_change(%{funnel: %{name: "My test funnel"}})
    lv
  end

  defp setup_goals(site, goal_names) when is_list(goal_names) do
    goals =
      Enum.map(goal_names, fn goal_name ->
        {:ok, g} = Plausible.Goals.create(site, %{"event_name" => goal_name})
        g
      end)

    {:ok, goals}
  end

  defp fake_options(option_names) do
    option_names
    |> Enum.shuffle()
    |> Enum.with_index(fn element, index -> {index, element} end)
  end
end
