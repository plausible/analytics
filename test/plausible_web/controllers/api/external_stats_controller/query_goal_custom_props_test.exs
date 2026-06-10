defmodule PlausibleWeb.Api.ExternalStatsController.QueryGoalCustomPropsTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  alias Plausible.Goals

  describe "goals with custom property filters" do
    test "filters custom event goals by custom properties", %{conn: conn, site: site} do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"variant" => "A"}
        })

      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["variant"],
          "meta.value": ["B"],
          timestamp: ~N[2021-01-01 00:00:03]
        ),
        build(:event,
          name: "Purchase",
          timestamp: ~N[2021-01-01 00:00:04]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "filters" => [["is", "event:goal", ["Purchase"]]]
        })

      resp = json_response(conn, 200)

      assert resp["results"] == [
               %{"dimensions" => [], "metrics" => [2, 2]}
             ]
    end

    test "filters with multiple custom properties (AND logic)", %{conn: conn, site: site} do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"variant" => "A", "plan" => "premium"}
        })

      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["variant", "plan"],
          "meta.value": ["A", "premium"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["variant", "plan"],
          "meta.value": ["A", "free"],
          user_id: 1
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["variant", "plan"],
          "meta.value": ["B", "premium"],
          user_id: 2
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          user_id: 3
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "filters" => [["is", "event:goal", ["Purchase"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => [], "metrics" => [1, 1]}
             ]
    end

    test "goals without custom_props filter match all events", %{conn: conn, site: site} do
      {:ok, _goal} = Goals.create(site, %{"event_name" => "Signup"})

      populate_stats(site, [
        build(:event,
          name: "Signup",
          "meta.key": ["source"],
          "meta.value": ["google"]
        ),
        build(:event,
          name: "Signup",
          "meta.key": ["source"],
          "meta.value": ["twitter"]
        ),
        build(:event, name: "Signup")
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "filters" => [["is", "event:goal", ["Signup"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => [], "metrics" => [3, 3]}
             ]
    end

    test "breakdown by event:goal with custom property filters", %{conn: conn, site: site} do
      {:ok, _g1} =
        Goals.create(site, %{
          "event_name" => "Purchase A",
          "custom_props" => %{"variant" => "A"}
        })

      {:ok, _g2} =
        Goals.create(site, %{
          "event_name" => "Purchase B",
          "custom_props" => %{"variant" => "B"}
        })

      populate_stats(site, [
        build(:event,
          name: "Purchase A",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          user_id: 1
        ),
        build(:event,
          name: "Purchase A",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          user_id: 1
        ),
        build(:event,
          name: "Purchase B",
          "meta.key": ["variant"],
          "meta.value": ["B"],
          user_id: 1
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["event:goal"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Purchase A"], "metrics" => [1, 2]},
               %{"dimensions" => ["Purchase B"], "metrics" => [1, 1]}
             ]
    end

    test "custom property filters work with conversion_rate metric", %{conn: conn, site: site} do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Signup",
          "custom_props" => %{"method" => "email"}
        })

      populate_stats(site, [
        build(:pageview, user_id: 1),
        build(:event,
          name: "Signup",
          "meta.key": ["method"],
          "meta.value": ["email"],
          user_id: 1
        ),
        build(:pageview, user_id: 2),
        build(:event,
          name: "Signup",
          "meta.key": ["method"],
          "meta.value": ["google"],
          user_id: 2
        ),
        build(:pageview, user_id: 3)
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events", "conversion_rate"],
          "filters" => [["is", "event:goal", ["Signup"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => [], "metrics" => [1, 1, 33.33]}
             ]
    end

    test "custom property filters work with multi-dimensional breakdown", %{
      conn: conn,
      site: site
    } do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"variant" => "A"}
        })

      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["variant", "plan"],
          "meta.value": ["A", "premium"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["variant", "plan"],
          "meta.value": ["A", "free"],
          user_id: 2
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["variant", "plan"],
          "meta.value": ["B", "premium"],
          user_id: 3
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["event:goal", "event:props:plan"],
          "filters" => [["is", "event:goal", ["Purchase"]]]
        })

      results = json_response(conn, 200)["results"]
      assert length(results) == 2
      assert Enum.member?(results, %{"dimensions" => ["Purchase", "free"], "metrics" => [1, 1]})

      assert Enum.member?(results, %{"dimensions" => ["Purchase", "premium"], "metrics" => [1, 1]})
    end

    test "custom property filters work with time series queries", %{conn: conn, site: site} do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Click",
          "custom_props" => %{"button" => "cta"}
        })

      populate_stats(site, [
        build(:event,
          name: "Click",
          "meta.key": ["button"],
          "meta.value": ["cta"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Click",
          "meta.key": ["button"],
          "meta.value": ["nav"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Click",
          "meta.key": ["button"],
          "meta.value": ["cta"],
          timestamp: ~N[2021-01-02 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => ["2021-01-01", "2021-01-02"],
          "metrics" => ["visitors"],
          "dimensions" => ["time:day"],
          "filters" => [["is", "event:goal", ["Click"]]]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [1]},
               %{"dimensions" => ["2021-01-02"], "metrics" => [1]}
             ]
    end

    test "different goals with same event name but different custom props are distinguished", %{
      conn: conn,
      site: site
    } do
      {:ok, _g1} =
        Goals.create(site, %{
          "event_name" => "Button Click",
          "display_name" => "Red Button",
          "custom_props" => %{"color" => "red"}
        })

      {:ok, _g2} =
        Goals.create(site, %{
          "event_name" => "Button Click",
          "display_name" => "Blue Button",
          "custom_props" => %{"color" => "blue"}
        })

      populate_stats(site, [
        build(:event,
          name: "Button Click",
          "meta.key": ["color"],
          "meta.value": ["red"],
          user_id: 1
        ),
        build(:event,
          name: "Button Click",
          "meta.key": ["color"],
          "meta.value": ["red"],
          user_id: 1
        ),
        build(:event,
          name: "Button Click",
          "meta.key": ["color"],
          "meta.value": ["blue"],
          user_id: 2
        ),
        build(:event, name: "Button Click", user_id: 3)
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["event:goal"]
        })

      results = json_response(conn, 200)["results"]

      assert Enum.find(results, &(&1["dimensions"] == ["Red Button"])) == %{
               "dimensions" => ["Red Button"],
               "metrics" => [1, 2]
             }

      assert Enum.find(results, &(&1["dimensions"] == ["Blue Button"])) == %{
               "dimensions" => ["Blue Button"],
               "metrics" => [1, 1]
             }

      refute Enum.find(results, &(&1["dimensions"] == ["Button Click"]))
    end
  end

  describe "goals with custom props and imported data" do
    setup :create_site_import

    test "filtering by a goal with custom props excludes imported data instead of crashing", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"variant" => "A"}
        })

      populate_stats(site, site_import.id, [
        build(:event,
          name: "Purchase",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          timestamp: ~N[2023-01-01 00:00:00]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2023-01-01]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "filters" => [["is", "event:goal", ["Purchase"]]],
          "include" => %{"imports" => true}
        })

      resp = json_response(conn, 200)

      # Imported data cannot be filtered by the goal's custom props,
      # so it must be excluded from the query.
      assert resp["results"] == [%{"dimensions" => [], "metrics" => [1, 1]}]
      refute resp["meta"]["imports_included"]
    end

    test "breakdown by event:goal does not attribute imported events to a goal with custom props",
         %{
           conn: conn,
           site: site,
           site_import: site_import
         } do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"variant" => "A"}
        })

      populate_stats(site, site_import.id, [
        build(:event,
          name: "Purchase",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          timestamp: ~N[2023-01-01 00:00:00]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2023-01-01]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["event:goal"],
          "include" => %{"imports" => true}
        })

      resp = json_response(conn, 200)

      # Imported events are aggregated by name only and cannot be checked
      # against the goal's custom props, so they must not be counted.
      assert resp["results"] == [%{"dimensions" => ["Purchase"], "metrics" => [1, 1]}]
    end

    test "breakdown by event:goal filtered by a goal with custom props excludes imported data instead of crashing",
         %{
           conn: conn,
           site: site,
           site_import: site_import
         } do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Purchase",
          "custom_props" => %{"variant" => "A"}
        })

      populate_stats(site, site_import.id, [
        build(:event,
          name: "Purchase",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          timestamp: ~N[2023-01-01 00:00:00]
        ),
        build(:imported_custom_events,
          name: "Purchase",
          visitors: 3,
          events: 5,
          date: ~D[2023-01-01]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "dimensions" => ["event:goal"],
          "filters" => [["is", "event:goal", ["Purchase"]]],
          "include" => %{"imports" => true}
        })

      resp = json_response(conn, 200)

      assert resp["results"] == [%{"dimensions" => ["Purchase"], "metrics" => [1, 1]}]
      refute resp["meta"]["imports_included"]
    end

    test "filtering by a custom property and a special goal with custom props excludes imported data instead of crashing",
         %{
           conn: conn,
           site: site,
           site_import: site_import
         } do
      {:ok, _goal} =
        Goals.create(site, %{
          "event_name" => "Outbound Link: Click",
          "custom_props" => %{"page_theme" => "dark"}
        })

      populate_stats(site, site_import.id, [
        build(:event,
          name: "Outbound Link: Click",
          "meta.key": ["url", "page_theme"],
          "meta.value": ["https://example.com", "dark"],
          timestamp: ~N[2023-01-01 00:00:00]
        ),
        build(:imported_custom_events,
          name: "Outbound Link: Click",
          link_url: "https://example.com",
          visitors: 3,
          events: 5,
          date: ~D[2023-01-01]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "events"],
          "filters" => [
            ["is", "event:goal", ["Outbound Link: Click"]],
            ["is", "event:props:url", ["https://example.com"]]
          ],
          "include" => %{"imports" => true}
        })

      resp = json_response(conn, 200)

      assert resp["results"] == [%{"dimensions" => [], "metrics" => [1, 1]}]
      refute resp["meta"]["imports_included"]
    end

    test "breakdown by event:goal does not attribute imported pageviews to a page goal with custom props",
         %{
           conn: conn,
           site: site,
           site_import: site_import
         } do
      {:ok, _goal} =
        Goals.create(site, %{
          "page_path" => "/checkout",
          "custom_props" => %{"variant" => "A"}
        })

      populate_stats(site, site_import.id, [
        build(:pageview,
          pathname: "/checkout",
          "meta.key": ["variant"],
          "meta.value": ["A"],
          timestamp: ~N[2023-01-01 00:00:00]
        ),
        build(:imported_pages,
          page: "/checkout",
          visitors: 3,
          pageviews: 5,
          date: ~D[2023-01-01]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors"],
          "dimensions" => ["event:goal"],
          "include" => %{"imports" => true}
        })

      resp = json_response(conn, 200)

      # Imported pageviews are aggregated by page only and cannot be checked
      # against the goal's custom props, so they must not be counted.
      assert resp["results"] == [%{"dimensions" => ["Visit /checkout"], "metrics" => [1]}]
    end
  end
end
