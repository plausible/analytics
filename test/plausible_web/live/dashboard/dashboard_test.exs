defmodule PlausibleWeb.Live.DashboardTest do
  use PlausibleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup [:create_user, :log_in, :create_site]

  setup %{site: site} do
    populate_stats(site, [build(:pageview)])

    :ok
  end

  describe "GET /:domain" do
    test "renders live dashboard container", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}")
      html = html_response(conn, 200)

      assert element_exists?(html, "#live-dashboard-container")
      assert element_exists?(html, "#pages-breakdown-live-container")
    end
  end

  describe "Live.Dashboard" do
    test "it works", %{conn: conn, site: site} do
      {lv, _html} = get_liveview(conn, site)
      assert has_element?(lv, "#pages-breakdown-live-container")
      assert has_element?(lv, "#breakdown-tile-pages")
      assert has_element?(lv, "#breakdown-tile-pages-tabs")
    end
  end

  defp get_liveview(conn, site) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.Dashboard)
    {:ok, lv, html} = live(conn, "/#{site.domain}")
    {lv, html}
  end
end
