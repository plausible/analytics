defmodule PlausibleWeb.Live.Dashboard.PagesTest do
  use PlausibleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Plausible.DashboardTestUtils

  setup [:create_user, :log_in, :create_site]

  @top_pages_report_list ~s|[data-test-id="pages-report-list"]|
  @entry_pages_report_list ~s|[data-test-id="entry-pages-report-list"]|
  @exit_pages_report_list ~s|[data-test-id="exit-pages-report-list"]|

  describe "Top Pages" do
    test "eventually renders and orders items by visitor counts", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/three"),
        build(:pageview, pathname: "/three"),
        build(:pageview, pathname: "/three")
      ])

      assert report_list = get_liveview(conn, site) |> get_report_list(@top_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Visitors"

      assert get_in_report_list(report_list, item_name: 0) =~ "/three"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "3"

      assert get_in_report_list(report_list, item_name: 1) =~ "/two"
      assert get_in_report_list(report_list, item: 1, metric: 0) =~ "2"

      assert get_in_report_list(report_list, item_name: 2) =~ "/one"
      assert get_in_report_list(report_list, item: 2, metric: 0) =~ "1"
    end

    test "renders current visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/two")
      ])

      assert report_list =
               get_liveview(conn, site, "period=realtime")
               |> get_report_list(@top_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Current visitors"

      assert get_in_report_list(report_list, item_name: 0) =~ "/two"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "2"

      assert get_in_report_list(report_list, item_name: 1) =~ "/one"
      assert get_in_report_list(report_list, item: 1, metric: 0) =~ "1"
    end

    test "renders conversions with conversion rate", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:event, name: "Signup", pathname: "/two"),
        build(:pageview, pathname: "/two")
      ])

      assert report_list =
               get_liveview(conn, site, "period=day&f=is,goal,Signup")
               |> get_report_list(@top_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Conversions"
      assert get_in_report_list(report_list, metric_label: 1) =~ "CR"

      assert get_in_report_list(report_list, item_name: 0) =~ "/two"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "1"
      assert get_in_report_list(report_list, item: 0, metric: 1) =~ "33.33%"

      refute get_in_report_list(report_list, item_name: 1)
    end
  end

  describe "Entry Pages" do
    test "eventually renders and orders items by visitor counts", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/three"),
        build(:pageview, pathname: "/three"),
        build(:pageview, pathname: "/three")
      ])

      assert report_list =
               get_liveview(conn, site)
               |> change_tab("entry-pages")
               |> get_report_list(@entry_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Entry page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Unique entrances"

      assert get_in_report_list(report_list, item_name: 0) =~ "/three"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "3"

      assert get_in_report_list(report_list, item_name: 1) =~ "/two"
      assert get_in_report_list(report_list, item: 1, metric: 0) =~ "2"

      assert get_in_report_list(report_list, item_name: 2) =~ "/one"
      assert get_in_report_list(report_list, item: 2, metric: 0) =~ "1"
    end

    test "renders current visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/two")
      ])

      assert report_list =
               get_liveview(conn, site, "period=realtime")
               |> change_tab("entry-pages")
               |> get_report_list(@entry_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Entry page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Current visitors"

      assert get_in_report_list(report_list, item_name: 0) =~ "/two"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "2"

      assert get_in_report_list(report_list, item_name: 1) =~ "/one"
      assert get_in_report_list(report_list, item: 1, metric: 0) =~ "1"
    end

    test "renders conversions with conversion rate", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, user_id: 1, pathname: "/two"),
        build(:event, user_id: 1, name: "Signup", pathname: "/two"),
        build(:pageview, pathname: "/two")
      ])

      assert report_list =
               get_liveview(conn, site, "period=day&f=is,goal,Signup")
               |> change_tab("entry-pages")
               |> get_report_list(@entry_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Entry page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Conversions"
      assert get_in_report_list(report_list, metric_label: 1) =~ "CR"

      assert get_in_report_list(report_list, item_name: 0) =~ "/two"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "1"
      assert get_in_report_list(report_list, item: 0, metric: 1) =~ "33.33%"

      refute get_in_report_list(report_list, item_name: 1)
    end
  end

  describe "Exit Pages" do
    test "eventually renders and orders items by visitor counts", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/three"),
        build(:pageview, pathname: "/three"),
        build(:pageview, pathname: "/three")
      ])

      assert report_list =
               get_liveview(conn, site)
               |> change_tab("exit-pages")
               |> get_report_list(@exit_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Exit page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Unique exits"

      assert get_in_report_list(report_list, item_name: 0) =~ "/three"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "3"

      assert get_in_report_list(report_list, item_name: 1) =~ "/two"
      assert get_in_report_list(report_list, item: 1, metric: 0) =~ "2"

      assert get_in_report_list(report_list, item_name: 2) =~ "/one"
      assert get_in_report_list(report_list, item: 2, metric: 0) =~ "1"
    end

    test "renders current visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/two")
      ])

      assert report_list =
               get_liveview(conn, site, "period=realtime")
               |> change_tab("exit-pages")
               |> get_report_list(@exit_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Exit page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Current visitors"

      assert get_in_report_list(report_list, item_name: 0) =~ "/two"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "2"

      assert get_in_report_list(report_list, item_name: 1) =~ "/one"
      assert get_in_report_list(report_list, item: 1, metric: 0) =~ "1"
    end

    test "renders conversions with conversion rate", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:event, user_id: 1, name: "Signup", pathname: "/two"),
        build(:pageview, user_id: 1, pathname: "/two"),
        build(:pageview, pathname: "/two")
      ])

      assert report_list =
               get_liveview(conn, site, "period=day&f=is,goal,Signup")
               |> change_tab("exit-pages")
               |> get_report_list(@exit_pages_report_list)

      assert get_in_report_list(report_list, :key_label) =~ "Exit page"
      assert get_in_report_list(report_list, metric_label: 0) =~ "Conversions"
      assert get_in_report_list(report_list, metric_label: 1) =~ "CR"

      assert get_in_report_list(report_list, item_name: 0) =~ "/two"
      assert get_in_report_list(report_list, item: 0, metric: 0) =~ "1"
      assert get_in_report_list(report_list, item: 0, metric: 1) =~ "33.33%"

      refute get_in_report_list(report_list, item_name: 1)
    end
  end

  defp get_report_list(lv, selector) do
    eventually(fn ->
      html = render(lv)
      {element_exists?(html, selector), find(html, selector)}
    end)
  end

  defp get_liveview(conn, site, search_params \\ "period=day") do
    conn = assign(conn, :live_module, PlausibleWeb.Live.Dashboard)
    {:ok, lv, _html} = live(conn, "/#{site.domain}?#{search_params}")
    lv
  end

  defp change_tab(lv, tab) do
    lv
    |> element("#breakdown-tile-pages-tabs")
    |> render_hook("set-tab", %{"tab" => tab})

    lv
  end
end
