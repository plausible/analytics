defmodule PlausibleWeb.Live.PropsSettings.FormTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  defp seed(%{site: site}) do
    populate_stats(site, [
      build(:event,
        name: "Payment",
        "meta.key": ["amount"],
        "meta.value": ["500"]
      ),
      build(:event,
        name: "Payment",
        "meta.key": ["amount", "logged_in"],
        "meta.value": ["100", "false"]
      ),
      build(:event,
        name: "Payment",
        "meta.key": ["amount", "is_customer"],
        "meta.value": ["100", "false"]
      )
    ])

    :ok
  end

  setup [:create_user, :log_in, :create_site, :seed]

  test "shows message when site has no allowed properties", %{conn: conn, site: site} do
    {:ok, _lv, doc} = get_liveview(conn, site)
    assert doc =~ "No properties configured for this site yet"
  end

  test "renders dropdown with suggestions", %{conn: conn, site: site} do
    {:ok, _lv, doc} = get_liveview(conn, site)

    assert text_of_element(doc, ~s/ul#dropdown-prop_input li#dropdown-prop_input-option-0/) ==
             "amount"

    assert text_of_element(doc, ~s/ul#dropdown-prop_input li#dropdown-prop_input-option-1/) ==
             "logged_in"

    assert text_of_element(doc, ~s/ul#dropdown-prop_input li#dropdown-prop_input-option-2/) ==
             "is_customer"
  end

  test "input is a required field", %{conn: conn, site: site} do
    {:ok, _lv, doc} = get_liveview(conn, site)
    assert element_exists?(doc, ~s/input#prop_input[required]/)
  end

  test "clicking suggestion fills out input", %{conn: conn, site: site} do
    {:ok, lv, _doc} = get_liveview(conn, site)

    doc =
      lv
      |> element(~s/ul#dropdown-prop_input li#dropdown-prop_input-option-0 a/)
      |> render_click()

    assert element_exists?(doc, ~s/input[type="hidden"][value="amount"]/)
  end

  test "saving from suggestion adds to the list", %{conn: conn, site: site} do
    {:ok, lv, _doc} = get_liveview(conn, site)

    doc = select_and_submit(lv, 0)

    assert text_of_element(doc, ~s/ul#allowed-props li#prop-0 span/) == "amount"
    refute doc =~ "No properties configured for this site yet"
  end

  test "saving from manual input adds to the list", %{conn: conn, site: site} do
    {:ok, lv, _doc} = get_liveview(conn, site)

    type_into_combo(lv, "Operating System")

    doc =
      lv
      |> form("#props-form")
      |> render_submit()

    assert text_of_element(doc, ~s/ul#allowed-props li#prop-0 span/) == "Operating System"
    refute doc =~ "No properties configured for this site yet"
  end

  test "shows error when input is invalid", %{conn: conn, site: site} do
    {:ok, lv, _doc} = get_liveview(conn, site)

    type_into_combo(lv, "   ")
    doc = lv |> form("#props-form") |> render_submit()

    assert text_of_element(doc, ~s/div#prop-errors div/) == "must be between 1 and 300 characters"
    assert doc =~ "No properties configured for this site yet"
  end

  test "shows error when reached prop limit", %{conn: conn, site: site} do
    props = for i <- 1..300, do: "my-prop-#{i}"
    {:ok, site} = Plausible.Props.allow(site, props)
    {:ok, lv, _doc} = get_liveview(conn, site)

    type_into_combo(lv, "my-prop-301")
    doc = lv |> form("#props-form") |> render_submit()

    assert text_of_element(doc, ~s/div#prop-errors div/) == "should have at most 300 item(s)"
  end

  test "clears error message when user fixes input", %{conn: conn, site: site} do
    {:ok, lv, _doc} = get_liveview(conn, site)

    type_into_combo(lv, "   ")
    doc = lv |> form("#props-form") |> render_submit()
    assert text_of_element(doc, ~s/div#prop-errors div/) == "must be between 1 and 300 characters"

    type_into_combo(lv, "my-prop")
    doc = lv |> form("#props-form") |> render_submit()
    refute element_exists?(doc, ~s/div#prop-errors/)
  end

  test "clicking remove button removes from the list", %{conn: conn, site: site} do
    {:ok, site} = Plausible.Props.allow(site, "my-prop")
    {:ok, lv, doc} = get_liveview(conn, site)

    assert text_of_element(doc, ~s/ul#allowed-props li#prop-0 span/) == "my-prop"

    doc =
      lv
      |> element(~s/ul#allowed-props li#prop-0 button[phx-click="disallow"]/)
      |> render_click()

    refute element_exists?(doc, ~s/ul#allowed-props li#prop-0 span/)
    assert doc =~ "No properties configured for this site yet"
  end

  test "remove button shows a confirmation popup", %{conn: conn, site: site} do
    {:ok, site} = Plausible.Props.allow(site, "my-prop")
    {:ok, _lv, doc} = get_liveview(conn, site)

    assert "Are you sure you want to remove property 'my-prop'? This will just affect the UI, all of your analytics data will stay intact." ==
             doc
             |> Floki.find(~s/ul#allowed-props li#prop-0 button[phx-click="disallow"]/)
             |> text_of_attr("data-confirm")
  end

  test "clicking allow existing props button saves props from events", %{conn: conn, site: site} do
    {:ok, lv, _doc} = get_liveview(conn, site)

    doc =
      lv
      |> element(~s/button[phx-click="allow-existing-props"]/)
      |> render_click()

    assert text_of_element(doc, ~s/ul#allowed-props li#prop-0 span/) == "amount"
    assert text_of_element(doc, ~s/ul#allowed-props li#prop-1 span/) == "logged_in"
    assert text_of_element(doc, ~s/ul#allowed-props li#prop-2 span/) == "is_customer"
  end

  test "does not show allow existing props button when there are no events with props", %{
    conn: conn,
    user: user
  } do
    {:ok, _lv, doc} = get_liveview(conn, insert(:site, members: [user]))
    refute element_exists?(doc, ~s/button[phx-click="allow-existing-props"]/)
  end

  test "does not show allow existing props button after adding all suggestions", %{
    conn: conn,
    site: site
  } do
    {:ok, lv, _doc} = get_liveview(conn, site)

    _doc = select_and_submit(lv, 0)
    _doc = select_and_submit(lv, 0)
    doc = select_and_submit(lv, 0)

    refute element_exists?(doc, ~s/button[phx-click="allow-existing-props"]/)
  end

  defp get_liveview(conn, site) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.PropsSettings)
    {:ok, _lv, _doc} = live(conn, "/#{site.domain}/settings/properties")
  end

  defp select_and_submit(lv, suggestion_index) do
    lv
    |> element(~s/ul#dropdown-prop_input li#dropdown-prop_input-option-#{suggestion_index} a/)
    |> render_click()

    lv
    |> form("#props-form")
    |> render_submit()
  end

  defp type_into_combo(lv, input) do
    lv
    |> element("input#prop_input")
    |> render_change(%{
      "_target" => ["display-prop_input"],
      "display-prop_input" => input
    })
  end
end
