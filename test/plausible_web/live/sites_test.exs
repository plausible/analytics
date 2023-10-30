defmodule PlausibleWeb.Live.SitesTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  setup [:create_user, :log_in]

  describe "/sites" do
    test "renders empty sites page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/sites")

      assert text(html) =~ "You don't have any sites yet"
    end

    test "filters by domain", %{conn: conn, user: user} do
      _site1 = insert(:site, domain: "first.example.com", members: [user])
      _site2 = insert(:site, domain: "second.example.com", members: [user])
      _site3 = insert(:site, domain: "first-another.example.com", members: [user])

      {:ok, lv, _html} = live(conn, "/sites")

      type_into_input(lv, "filter_text", "firs")
      html = render(lv)

      assert html =~ "first.example.com"
      assert html =~ "first-another.example.com"
      refute html =~ "second.example.com"
    end

    test "filtering plays well with pagination", %{conn: conn, user: user} do
      _site1 = insert(:site, domain: "first.another.example.com", members: [user])
      _site2 = insert(:site, domain: "second.example.com", members: [user])
      _site3 = insert(:site, domain: "third.another.example.com", members: [user])

      {:ok, lv, html} = live(conn, "/sites?limit=2")

      assert html =~ "first.another.example.com"
      assert html =~ "second.example.com"
      refute html =~ "third.another.example.com"
      assert html =~ "after="
      refute html =~ "before="

      type_into_input(lv, "filter_text", "anot")
      html = render(lv)

      assert html =~ "first.another.example.com"
      refute html =~ "second.example.com"
      assert html =~ "third.another.example.com"
      refute html =~ "after="
      refute html =~ "before="
    end
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form")
    |> render_change(%{id => text})
  end
end
