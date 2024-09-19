defmodule PlausibleWeb.Api.InternalController.DocsQueryTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo
  @user_id Enum.random(1000..9999)

  describe "POST /api/docs/query not logged in" do
    setup [:create_user, :create_new_site]

    test "rejects request when not logged in", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/docs/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => "all"
        })

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end
  end

  describe "POST /api/docs/query logged in" do
    setup [:create_user, :create_new_site, :log_in]

    test "rejects when accessing any other site", %{conn: conn} do
      conn =
        post(conn, "/api/docs/query", %{
          "site_id" => "any.other.site",
          "metrics" => ["pageviews"],
          "date_range" => "all"
        })

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end

    test "returns aggregated metrics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, user_id: @user_id, timestamp: ~N[2021-01-01 00:25:00]),
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00])
      ])

      conn =
        post(conn, "/api/docs/query?site_id=ignored", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => "all"
        })

      assert json_response(conn, 200)["results"] == [%{"metrics" => [3], "dimensions" => []}]
    end
  end
end
