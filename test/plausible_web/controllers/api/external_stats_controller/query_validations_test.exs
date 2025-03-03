defmodule PlausibleWeb.Api.ExternalStatsController.QueryValidationsTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  alias Plausible.Billing.Feature

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  describe "feature access" do
    test "cannot break down by a custom prop without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      subscribe_to_enterprise_plan(user, features: [Feature.StatsAPI])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:author"]
        })

      assert json_response(conn, 400)["error"] ==
               "The owner of this site does not have access to the custom properties feature."
    end

    test "can break down by an internal prop key without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      subscribe_to_enterprise_plan(user, features: [Feature.StatsAPI])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:path"]
        })

      assert json_response(conn, 200)["results"]
    end

    test "cannot filter by a custom prop without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      subscribe_to_enterprise_plan(user, features: [Feature.StatsAPI])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [["is", "event:props:author", ["Uku"]]]
        })

      assert json_response(conn, 400)["error"] ==
               "The owner of this site does not have access to the custom properties feature."
    end

    test "can filter by an internal prop key without access to the props feature", %{
      conn: conn,
      user: user,
      site: site
    } do
      subscribe_to_enterprise_plan(user, features: [Feature.StatsAPI])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [["is", "event:props:url", ["whatever"]]]
        })

      assert json_response(conn, 200)["results"]
    end
  end

  describe "param validation" do
    test "does not allow querying conversion_rate without a goal filter", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["conversion_rate"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [["is", "event:props:author", ["Uku"]]]
        })

      assert json_response(conn, 400)["error"] ==
               "Metric `conversion_rate` can only be queried with event:goal filters or dimensions."
    end

    test "validates that dimensions are valid", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["badproperty"]
        })

      assert json_response(conn, 400)["error"] ==
               "#/dimensions/0: Invalid dimension \"badproperty\""
    end

    test "empty custom property is invalid", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:props:"]
        })

      assert json_response(conn, 400)["error"] ==
               "#/dimensions/0: Invalid dimension \"event:props:\""
    end

    test "validates that correct date range is used", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "bad_period",
          "dimensions" => ["event:name"]
        })

      assert json_response(conn, 400)["error"] ==
               "#/date_range: Invalid date range \"bad_period\""
    end

    test "fails when an invalid metric is provided", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "baa"],
          "date_range" => "all",
          "dimensions" => ["event:name"]
        })

      assert json_response(conn, 400)["error"] == "#/metrics/1: Invalid metric \"baa\""
    end

    test "session metrics cannot be used with event:name dimension", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "bounce_rate"],
          "date_range" => "all",
          "dimensions" => ["event:name"]
        })

      assert json_response(conn, 400)["error"] =~
               "Session metric(s) `bounce_rate` cannot be queried along with event dimension(s) `event:name`"
    end

    test "session metrics cannot be used with event:props:* dimension", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "bounce_rate"],
          "date_range" => "all",
          "dimensions" => ["event:props:url"]
        })

      assert json_response(conn, 400)["error"] =~
               "Session metric(s) `bounce_rate` cannot be queried along with event dimension(s) `event:props:url`"
    end

    test "validates that metric views_per_visit cannot be used with event:page filter", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["views_per_visit"],
          "filters" => [["is", "event:page", ["/something"]]]
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Metric `views_per_visit` cannot be queried with a filter on `event:page`."
             }
    end

    test "validates that metric views_per_visit cannot be used together with dimensions", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["views_per_visit"],
          "dimensions" => ["event:name"]
        })

      assert json_response(conn, 400) == %{
               "error" => "Metric `views_per_visit` cannot be queried with `dimensions`."
             }
    end

    test "validates a metric can't be asked multiple times", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["views_per_visit", "visitors", "visitors"]
        })

      assert json_response(conn, 400) == %{
               "error" => "#/metrics: Expected items to be unique but they were not."
             }
    end

    test "handles filtering by visit:country with invalid country code", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "EE"),
        build(:pageview, country_code: "IT"),
        build(:pageview, country_code: "DE")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["pageviews"],
          "filters" => [["is", "visit:country", ["USA"]]]
        })

      assert json_response(conn, 400) == %{
               "error" =>
                 "Invalid visit:country filter, visit:country needs to be a valid 2-letter country code."
             }
    end
  end
end
