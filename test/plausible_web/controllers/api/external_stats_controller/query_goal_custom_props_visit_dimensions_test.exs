defmodule PlausibleWeb.Api.ExternalStatsController.QueryGoalCustomPropsVisitDimensionsTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  alias Plausible.Goals

  describe "visit dimensions filtered by goals with custom props" do
    test "filters visit:country by goal with custom props correctly", %{conn: conn, site: site} do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Signup",
          "custom_props" => %{"plan" => "premium"}
        })

      populate_stats(site, [
        # Session 1 (US): Has correct event (Signup with plan=premium)
        build(:pageview,
          user_id: 1,
          country_code: "US",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 1,
          name: "Signup",
          "meta.key": ["plan"],
          "meta.value": ["premium"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # Session 2 (GB): Has wrong event (Signup with plan=basic)
        build(:pageview,
          user_id: 2,
          country_code: "GB",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 2,
          name: "Signup",
          "meta.key": ["plan"],
          "meta.value": ["basic"],
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        # Session 3 (CA): Has event with event name but no custom props
        build(:pageview,
          user_id: 3,
          country_code: "CA",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 4,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        # Session 4 (DE): Has no Signup event at all
        build(:pageview,
          user_id: 5,
          country_code: "DE",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["visit:country"],
          "filters" => [["is", "event:goal", ["Signup"]]]
        })

      resp = json_response(conn, 200)

      # Only session 1 (US) should be included, as it's the only one with
      # the correct event name AND matching custom props
      assert resp["results"] == [
               %{"dimensions" => ["US"], "metrics" => [1, 1]}
             ]
    end

    test "filters visit:browser by goal with multiple custom props", %{conn: conn, site: site} do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"variant" => "A", "tier" => "gold"}
        })

      populate_stats(site, [
        # Chrome - matches both props
        build(:pageview,
          user_id: 1,
          browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 1,
          name: "Purchase",
          "meta.key": ["variant", "tier"],
          "meta.value": ["A", "gold"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # Firefox - matches only variant, not tier
        build(:pageview,
          user_id: 2,
          browser: "Firefox",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 3,
          name: "Purchase",
          "meta.key": ["variant", "tier"],
          "meta.value": ["A", "silver"],
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        # Safari - matches only tier, not variant
        build(:pageview,
          user_id: 4,
          browser: "Safari",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 5,
          name: "Purchase",
          "meta.key": ["variant", "tier"],
          "meta.value": ["B", "gold"],
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        # Edge - has event name but missing custom props entirely
        build(:pageview,
          user_id: 6,
          browser: "Edge",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 7,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:04]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["visit:browser"],
          "filters" => [["is", "event:goal", ["Purchase"]]]
        })

      resp = json_response(conn, 200)

      # Only session 1 (Chrome) should be included
      assert resp["results"] == [
               %{"dimensions" => ["Chrome"], "metrics" => [1, 1]}
             ]
    end

    test "filters visit:city by goal with custom props", %{conn: conn, site: site} do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Download",
          "custom_props" => %{"file_type" => "pdf"}
        })

      populate_stats(site, [
        # San Francisco - correct props
        build(:pageview,
          user_id: 1,
          city_geoname_id: 5_391_959,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 1,
          name: "Download",
          "meta.key": ["file_type"],
          "meta.value": ["pdf"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # New York - wrong prop value
        build(:pageview,
          user_id: 2,
          city_geoname_id: 5_128_581,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 3,
          name: "Download",
          "meta.key": ["file_type"],
          "meta.value": ["docx"],
          timestamp: ~N[2021-01-01 00:00:02]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["visit:city"],
          "filters" => [["is", "event:goal", ["Download"]]]
        })

      resp = json_response(conn, 200)

      # Only San Francisco session should be included
      assert length(resp["results"]) == 1
      assert [%{"dimensions" => [5_391_959], "metrics" => [1, 1]}] = resp["results"]
    end

    test "filters visit:os by goal with custom prop containing special characters", %{
      conn: conn,
      site: site
    } do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Custom Event",
          "custom_props" => %{"tag" => "test-value"}
        })

      populate_stats(site, [
        # Mac - correct props
        build(:pageview,
          user_id: 1,
          operating_system: "Mac",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 1,
          name: "Custom Event",
          "meta.key": ["tag"],
          "meta.value": ["test-value"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # Windows - wrong value
        build(:pageview,
          user_id: 2,
          operating_system: "Windows",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 2,
          name: "Custom Event",
          "meta.key": ["tag"],
          "meta.value": ["other-value"],
          timestamp: ~N[2021-01-01 00:00:02]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["visit:os"],
          "filters" => [["is", "event:goal", ["Custom Event"]]]
        })

      resp = json_response(conn, 200)

      # Only Mac session should be included
      assert resp["results"] == [
               %{"dimensions" => ["Mac"], "metrics" => [1, 1]}
             ]
    end

    test "works with additional visit dimension filters combined", %{conn: conn, site: site} do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Newsletter",
          "custom_props" => %{"source" => "sidebar"}
        })

      populate_stats(site, [
        # US/Chrome - correct props
        build(:pageview,
          user_id: 1,
          country_code: "US",
          browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 1,
          name: "Newsletter",
          "meta.key": ["source"],
          "meta.value": ["sidebar"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # US/Firefox - wrong props
        build(:pageview,
          user_id: 2,
          country_code: "US",
          browser: "Firefox",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 2,
          name: "Newsletter",
          "meta.key": ["source"],
          "meta.value": ["footer"],
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        # GB/Chrome - correct props
        build(:pageview,
          user_id: 3,
          country_code: "GB",
          browser: "Chrome",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 3,
          name: "Newsletter",
          "meta.key": ["source"],
          "meta.value": ["sidebar"],
          timestamp: ~N[2021-01-01 00:00:03]
        )
      ])

      # Filter by goal with custom props AND by country=US
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["visit:browser"],
          "filters" => [
            ["is", "event:goal", ["Newsletter"]],
            ["is", "visit:country", ["US"]]
          ]
        })

      resp = json_response(conn, 200)

      # Only session 1 (US/Chrome + correct props) should match
      assert resp["results"] == [
               %{"dimensions" => ["Chrome"], "metrics" => [1, 1]}
             ]
    end

    test "handles multiple goal filters with different custom props", %{conn: conn, site: site} do
      {:ok, _goal1} =
        Goals.create(site, %{
          "event_name" => "Action A",
          "custom_props" => %{"type" => "alpha"}
        })

      {:ok, _goal2} =
        Goals.create(site, %{
          "event_name" => "Action B",
          "custom_props" => %{"type" => "beta"}
        })

      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          country_code: "US",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 1,
          name: "Action A",
          "meta.key": ["type"],
          "meta.value": ["alpha"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        build(:pageview,
          user_id: 2,
          country_code: "GB",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 2,
          name: "Action B",
          "meta.key": ["type"],
          "meta.value": ["beta"],
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        build(:pageview,
          user_id: 3,
          country_code: "CA",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 3,
          name: "Action A",
          "meta.key": ["type"],
          "meta.value": ["gamma"],
          timestamp: ~N[2021-01-01 00:00:03]
        )
      ])

      # Query for both goals (OR logic)
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["visit:country"],
          "filters" => [["is", "event:goal", ["Action A", "Action B"]]]
        })

      resp = json_response(conn, 200)

      # Should match sessions 1 and 2 (both with correct props), but not 3
      assert length(resp["results"]) == 2

      assert Enum.sort(resp["results"]) == [
               %{"dimensions" => ["GB"], "metrics" => [1, 1]},
               %{"dimensions" => ["US"], "metrics" => [1, 1]}
             ]
    end
  end
end
