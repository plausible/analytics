defmodule PlausibleWeb.Api.InternalController.QueryTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo

  describe "POST /api/:domain/query shared/public" do
    test "returns aggregated metrics for public site", %{conn: conn} do
      site = new_site(public: true)

      populate_stats(site, [
        build(:pageview, user_id: 5, pathname: "/foo", timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/stats/#{URI.encode(site.domain)}/query", %{
          "metrics" => ["pageviews"],
          "date_range" => "all",
          "filters" => [["is", "event:page", ["/foo"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"metrics" => [1], "dimensions" => []}
             ]
    end

    test "returns aggregated metrics with shared link auth", %{conn: conn} do
      site = new_site()

      populate_stats(site, [
        build(:pageview, user_id: 5, pathname: "/foo", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 5, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      link = insert(:shared_link, site: site)

      conn =
        post(conn, "/api/stats/#{URI.encode(site.domain)}/query?auth=#{link.slug}", %{
          "metrics" => ["pageviews"],
          "date_range" => "all",
          "filters" => [["is", "event:page", ["/foo"]]]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [1], "dimensions" => []}]
    end

    test "returns metrics with shared link auth that is limited to segment", %{conn: conn} do
      site = new_site()

      populate_stats(site, [
        build(:pageview, user_id: 5, pathname: "/foo", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 5, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      segment =
        insert(:segment,
          site: site,
          name: "Scandinavia",
          type: :site,
          segment_data: %{"filters" => [["is", "event:page", ["/foo"]]]}
        )

      link = insert(:shared_link, segment_id: segment.id, site: site)

      conn =
        post(conn, "/api/stats/#{URI.encode(site.domain)}/query?auth=#{link.slug}", %{
          "metrics" => ["pageviews"],
          "date_range" => "all",
          "filters" => [["is", "segment", [segment.id]]]
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [1], "dimensions" => []}]
    end

    test "errors when expected segment filter not present for shared link auth that is limited to segment",
         %{conn: conn} do
      site = new_site()

      segment =
        insert(:segment,
          site: site,
          name: "Scandinavia",
          type: :site,
          segment_data: %{"filters" => [["is", "event:page", ["/foo"]]]}
        )

      link = insert(:shared_link, segment_id: segment.id, site: site)

      conn =
        post(conn, "/api/stats/#{URI.encode(site.domain)}/query?auth=#{link.slug}", %{
          "metrics" => ["pageviews"],
          "date_range" => "all",
          "filters" => []
        })

      assert json_response(conn, 400) == %{
               "error" => "The first filter must be for the segment with id #{segment.id}"
             }
    end
  end

  describe "POST /api/:domain/query" do
    setup [:create_user, :create_site, :log_in]

    test "rejects when accessing any other site", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/stats/any.other.site/query", %{
          # ignored
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => "all",
          "filters" => []
        })

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end

    test "returns aggregated metrics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 5, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: 5, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/stats/#{URI.encode(site.domain)}/query?site_id=ignored", %{
          "metrics" => ["pageviews"],
          "date_range" => "all",
          "filters" => []
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end
  end
end
