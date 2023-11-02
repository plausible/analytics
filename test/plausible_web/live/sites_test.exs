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

    test "renders 24h visitors correctly", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      populate_stats(site, [build(:pageview), build(:pageview), build(:pageview)])

      {:ok, _lv, html} = live(conn, "/sites")

      site_card = text_of_element(html, "li[data-domain=\"#{site.domain}\"]")
      assert site_card =~ "3 visitors in last 24h"
      assert site_card =~ site.domain
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

      {:ok, lv, html} = live(conn, "/sites?page_size=2")

      assert html =~ "first.another.example.com"
      assert html =~ "second.example.com"
      refute html =~ "third.another.example.com"
      assert html =~ "page=2"
      refute html =~ "page=1"

      type_into_input(lv, "filter_text", "anot")
      html = render(lv)

      assert html =~ "first.another.example.com"
      refute html =~ "second.example.com"
      assert html =~ "third.another.example.com"
      refute html =~ "page=1"
      refute html =~ "page=2"
    end
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form")
    |> render_change(%{id => text})
  end
end
