defmodule PlausibleWeb.Live.Dashboard.PagesTest do
  use PlausibleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Plausible.DashboardTestUtils

  setup [:create_user, :log_in, :create_site]

  @top_pages_report_list ~s|[data-test-id="pages-report-list"]|
  @entry_pages_report_list ~s|[data-test-id="entry-pages-report-list"]|
  @exit_pages_report_list ~s|[data-test-id="exit-pages-report-list"]|
  @unsupported_filters_warning ~s|#breakdown-tile-pages [data-test-id="unsupported-filters-warning"]|

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

      assert report_list = get_liveview(conn, site) |> wait_for_element(@top_pages_report_list)

      assert report_list_as_table(report_list, 4, 2) == [
               ["Page", "Visitors"],
               ["/three", "3"],
               ["/two", "2"],
               ["/one", "1"]
             ]
    end

    test "renders current visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/two")
      ])

      assert report_list =
               get_liveview(conn, site, "period=realtime")
               |> wait_for_element(@top_pages_report_list)

      assert report_list_as_table(report_list, 3, 2) == [
               ["Page", "Current visitors"],
               ["/two", "2"],
               ["/one", "1"]
             ]
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
               |> wait_for_element(@top_pages_report_list)

      assert report_list_as_table(report_list, 2, 3) == [
               ["Page", "Conversions", "CR"],
               ["/two", "1", "50.00%"]
             ]

      refute get_in_report_list(report_list, 2, 0)
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
               |> wait_for_element(@entry_pages_report_list)

      assert report_list_as_table(report_list, 4, 2) == [
               ["Entry page", "Unique entrances"],
               ["/three", "3"],
               ["/two", "2"],
               ["/one", "1"]
             ]
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
               |> wait_for_element(@entry_pages_report_list)

      assert report_list_as_table(report_list, 3, 2) == [
               ["Entry page", "Current visitors"],
               ["/two", "2"],
               ["/one", "1"]
             ]
    end

    test "renders conversions with conversion rate", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, pathname: "/one"),
        build(:pageview, pathname: "/two"),
        build(:pageview, pathname: "/two"),
        build(:pageview, user_id: 1, pathname: "/two"),
        build(:event, user_id: 1, name: "Signup", pathname: "/two")
      ])

      assert report_list =
               get_liveview(conn, site, "period=day&f=is,goal,Signup")
               |> change_tab("entry-pages")
               |> wait_for_element(@entry_pages_report_list)

      assert report_list_as_table(report_list, 2, 3) == [
               ["Entry page", "Conversions", "CR"],
               ["/two", "1", "33.33%"]
             ]

      refute get_in_report_list(report_list, 2, 0)
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
               |> wait_for_element(@exit_pages_report_list)

      assert report_list_as_table(report_list, 4, 2) == [
               ["Exit page", "Unique exits"],
               ["/three", "3"],
               ["/two", "2"],
               ["/one", "1"]
             ]
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
               |> wait_for_element(@exit_pages_report_list)

      assert report_list_as_table(report_list, 3, 2) == [
               ["Exit page", "Current visitors"],
               ["/two", "2"],
               ["/one", "1"]
             ]
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
               |> wait_for_element(@exit_pages_report_list)

      assert report_list_as_table(report_list, 2, 3) == [
               ["Exit page", "Conversions", "CR"],
               ["/two", "1", "50.00%"]
             ]

      refute get_in_report_list(report_list, 2, 0)
    end
  end

  describe "unsupported filters warning" do
    setup %{site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:pageview, timestamp: ~N[2021-01-02 00:00:00]),
        build(:imported_visitors, visitors: 1, date: ~D[2021-01-01]),
        build(:imported_pages, page: "/", visitors: 1, date: ~D[2021-01-01])
      ])

      :ok
    end

    test "shows up when mixing dimensions", %{conn: conn, site: site} do
      tooltip_element =
        get_liveview(conn, site, "period=all&f=is,browser,Chrome")
        |> wait_for_element(@unsupported_filters_warning)

      assert text(tooltip_element) =~ "Imported data is excluded due to the applied filters"
    end

    test "does not show up when mixing dimensions but imports not requested", %{
      conn: conn,
      site: site
    } do
      lv = get_liveview(conn, site, "period=all&f=is,browser,Chrome&with_imported=false")
      _report_list = wait_for_element(lv, @top_pages_report_list)
      html = render(lv)

      refute element_exists?(html, @unsupported_filters_warning)
    end

    test "does not show up when imports are included in the data", %{conn: conn, site: site} do
      lv = get_liveview(conn, site, "period=all")
      _report_list = wait_for_element(lv, @top_pages_report_list)
      html = render(lv)

      refute element_exists?(html, @unsupported_filters_warning)
    end

    test "does not show up when imports don't exist", %{conn: conn, user: user} do
      site_without_imports = new_site(owner: user, stats_start_date: ~D[2021-01-01])

      lv = get_liveview(conn, site_without_imports, "period=all")
      _report_list = wait_for_element(lv, @top_pages_report_list)
      html = render(lv)

      refute element_exists?(html, @unsupported_filters_warning)
    end

    test "does not show up when imports exist but out of range", %{conn: conn, site: site} do
      lv = get_liveview(conn, site, "period=day")
      _report_list = wait_for_element(lv, @top_pages_report_list)
      html = render(lv)

      refute element_exists?(html, @unsupported_filters_warning)
    end
  end

  defp wait_for_element(lv, selector) do
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
