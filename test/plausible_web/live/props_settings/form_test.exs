defmodule PlausibleWeb.Live.PropsSettings.FormTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "Props submission" do
    setup [:create_user, :log_in, :create_site]

    test "renders form fields", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = render(lv)

      assert element_exists?(html, "form input[type=text][name=display-prop_input]")
      assert element_exists?(html, "form input[type=hidden][name=prop]")
    end

    test "renders error on empty submission", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = lv |> element("form") |> render_submit()
      assert html =~ "must be between 1 and 300 characters"
    end

    test "renders error on whitespace submission", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      html = lv |> element("form") |> render_submit(%{prop: "     "})
      assert html =~ "must be between 1 and 300 characters"
    end

    test "renders 'Create' suggestion", %{conn: conn, site: site} do
      lv = get_liveview(conn, site)
      type_into_combo(lv, "#prop_input", "Hello world")
      html = render(lv)
      assert text_of_element(html, "#dropdown-prop_input-option-0 a") == ~s/Create "Hello world"/
    end

    test "clicking suggestion fills out input", %{conn: conn, site: site} = context do
      seed_props(context)
      lv = get_liveview(conn, site)
      type_into_combo(lv, "#prop_input", "amo")

      doc =
        lv
        |> element(~s/ul#dropdown-prop_input li#dropdown-prop_input-option-1 a/)
        |> render_click()

      assert element_exists?(doc, ~s/input[type="hidden"][value="amount"]/)
    end

    test "allowing a single property", %{conn: conn, site: site} do
      {parent, lv} = get_liveview(conn, site, with_parent?: true)
      refute render(parent) =~ "foobarbaz"
      lv |> element("form") |> render_submit(%{prop: "foobarbaz"})
      parent_html = render(parent)
      assert text_of_element(parent_html, "#prop-0") == "foobarbaz"

      site = Plausible.Repo.reload!(site)
      assert site.allowed_event_props == ["foobarbaz"]
    end

    test "allowing existing properties", %{conn: conn, site: site} = context do
      seed_props(context)
      {parent, lv} = get_liveview(conn, site, with_parent?: true)
      parent_html = render(parent)
      refute element_exists?(parent_html, "#prop-0")
      refute element_exists?(parent_html, "#prop-1")
      refute element_exists?(parent_html, "#prop-2")

      lv
      |> element(~s/button[phx-click="allow-existing-props"]/)
      |> render_click()

      parent_html = render(parent)
      assert text_of_element(parent_html, "#prop-0") == "amount"
      assert text_of_element(parent_html, "#prop-1") == "logged_in"
      assert text_of_element(parent_html, "#prop-2") == "is_customer"

      site = Plausible.Repo.reload!(site)
      assert site.allowed_event_props == ["amount", "logged_in", "is_customer"]
    end

    test "does not show allow existing props button when there are no events with props", %{
      conn: conn,
      site: site
    } do
      lv = get_liveview(conn, site)
      refute element_exists?(render(lv), ~s/button[phx-click="allow-existing-props"]/)
    end

    test "does not show allow existing props button after adding all suggestions",
         %{
           conn: conn,
           site: site
         } = context do
      seed_props(context)

      conn
      |> get_liveview(site)
      |> element(~s/button[phx-click="allow-existing-props"]/)
      |> render_click()

      site = Plausible.Repo.reload!(site)
      assert site.allowed_event_props == ["amount", "logged_in", "is_customer"]

      html =
        conn
        |> get_liveview(site)
        |> render()

      refute element_exists?(html, ~s/button[phx-click="allow-existing-props"]/)
    end
  end

  defp seed_props(%{site: site}) do
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

  defp get_liveview(conn, site, opts \\ []) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.PropsSettings)
    {:ok, lv, _html} = live(conn, "/#{site.domain}/settings/properties")
    lv |> element(~s/button[phx-click="add-prop"]/) |> render_click()
    assert form_view = find_live_child(lv, "props-form")

    if opts[:with_parent?] do
      {lv, form_view}
    else
      form_view
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
end
