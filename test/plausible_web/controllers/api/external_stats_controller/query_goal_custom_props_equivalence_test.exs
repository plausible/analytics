defmodule PlausibleWeb.Api.ExternalStatsController.QueryGoalCustomPropsEquivalenceTest do
  @moduledoc """
  Tests that filtering by a goal with custom props produces the same results
  as filtering by the goal without custom props AND a separate custom prop filter.

  For example, these two queries should return identical results:
  1. Filter by goal "Visit /" with custom_props: {"browser_language" => "FR"}
  2. Filter by goal "Visit /" (no custom props) AND filter by event:props:browser_language = "FR"
  """
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  alias Plausible.Goals

  describe "goal with custom props equivalence" do
    test "page goal with custom props equals page goal + separate prop filter", %{
      conn: conn,
      site: site
    } do
      # Create page goal WITH custom props
      {:ok, _goal_with_props} =
        Goals.create(site, %{
          "page_path" => "/landing",
          "custom_props" => %{"browser_language" => "FR"}
        })

      # Create page goal WITHOUT custom props
      {:ok, _goal_without_props} =
        Goals.create(site, %{
          "page_path" => "/landing-no-props"
        })

      populate_stats(site, [
        # Session 1 (FR): Has pageview with browser_language=FR
        build(:pageview,
          user_id: 1,
          pathname: "/landing",
          country_code: "FR",
          "meta.key": ["browser_language"],
          "meta.value": ["FR"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/landing-no-props",
          country_code: "FR",
          "meta.key": ["browser_language"],
          "meta.value": ["FR"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # Session 2 (US): Has pageview with browser_language=EN
        build(:pageview,
          user_id: 2,
          pathname: "/landing",
          country_code: "US",
          "meta.key": ["browser_language"],
          "meta.value": ["EN"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/landing-no-props",
          country_code: "US",
          "meta.key": ["browser_language"],
          "meta.value": ["EN"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # Session 3 (GB): Has pageview with no props
        build(:pageview,
          user_id: 3,
          pathname: "/landing",
          country_code: "GB",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 3,
          pathname: "/landing-no-props",
          country_code: "GB",
          timestamp: ~N[2021-01-01 00:00:01]
        )
      ])

      # Query 1: Page goal with custom props
      conn1 =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "visits", "events"],
          "dimensions" => ["visit:country"],
          "filters" => [["is", "event:goal", ["Visit /landing"]]]
        })

      result1 = json_response(conn1, 200)["results"]

      # Query 2: Page goal without props + separate prop filter
      conn2 =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "visits", "events"],
          "dimensions" => ["visit:country"],
          "filters" => [
            ["is", "event:goal", ["Visit /landing-no-props"]],
            ["is", "event:props:browser_language", ["FR"]]
          ]
        })

      result2 = json_response(conn2, 200)["results"]

      # Both should return only FR
      assert result1 == [%{"dimensions" => ["FR"], "metrics" => [1, 1, 1]}]
      assert result2 == [%{"dimensions" => ["FR"], "metrics" => [1, 1, 1]}]
      assert result1 == result2
    end

    test "event goal with custom props equals event goal + separate prop filter", %{
      conn: conn,
      site: site
    } do
      # Create event goal WITH custom props
      {:ok, _goal_with_props} =
        Goals.create(site, %{
          "event_name" => "Signup",
          "custom_props" => %{"plan" => "premium"}
        })

      # Create event goal WITHOUT custom props
      {:ok, _goal_without_props} =
        Goals.create(site, %{
          "event_name" => "SignupNoProps"
        })

      populate_stats(site, [
        # Session 1 (US): Has correct event with plan=premium
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
        build(:event,
          user_id: 1,
          name: "SignupNoProps",
          "meta.key": ["plan"],
          "meta.value": ["premium"],
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        # Session 2 (GB): Has event with plan=basic
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
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        build(:event,
          user_id: 2,
          name: "SignupNoProps",
          "meta.key": ["plan"],
          "meta.value": ["basic"],
          timestamp: ~N[2021-01-01 00:00:02]
        ),
        # Session 3 (CA): Has event but no props at all
        build(:pageview,
          user_id: 3,
          country_code: "CA",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          user_id: 3,
          name: "Signup",
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        build(:event,
          user_id: 3,
          name: "SignupNoProps",
          timestamp: ~N[2021-01-01 00:00:02]
        )
      ])

      # Query 1: Event goal with custom props
      conn1 =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "visits", "events"],
          "dimensions" => ["visit:country"],
          "filters" => [["is", "event:goal", ["Signup"]]]
        })

      result1 = json_response(conn1, 200)["results"]

      # Query 2: Event goal without props + separate prop filter
      conn2 =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "visits", "events"],
          "dimensions" => ["visit:country"],
          "filters" => [
            ["is", "event:goal", ["SignupNoProps"]],
            ["is", "event:props:plan", ["premium"]]
          ]
        })

      result2 = json_response(conn2, 200)["results"]

      # Both should return only US
      assert result1 == [%{"dimensions" => ["US"], "metrics" => [1, 1, 1]}]
      assert result2 == [%{"dimensions" => ["US"], "metrics" => [1, 1, 1]}]
      assert result1 == result2
    end

    test "page goal with multiple custom props equals page goal + multiple separate prop filters",
         %{conn: conn, site: site} do
      # Create page goal WITH multiple custom props
      {:ok, _goal_with_props} =
        Goals.create(site, %{
          "page_path" => "/checkout",
          "custom_props" => %{"currency" => "EUR", "country" => "DE"}
        })

      # Create page goal WITHOUT custom props
      {:ok, _goal_without_props} =
        Goals.create(site, %{
          "page_path" => "/checkout-no-props"
        })

      populate_stats(site, [
        # Session 1 (DE): Has pageview with both props matching
        build(:pageview,
          user_id: 1,
          pathname: "/checkout",
          country_code: "DE",
          "meta.key": ["currency", "country"],
          "meta.value": ["EUR", "DE"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          pathname: "/checkout-no-props",
          country_code: "DE",
          "meta.key": ["currency", "country"],
          "meta.value": ["EUR", "DE"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # Session 2 (FR): Has pageview with only currency matching
        build(:pageview,
          user_id: 2,
          pathname: "/checkout",
          country_code: "FR",
          "meta.key": ["currency", "country"],
          "meta.value": ["EUR", "FR"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 2,
          pathname: "/checkout-no-props",
          country_code: "FR",
          "meta.key": ["currency", "country"],
          "meta.value": ["EUR", "FR"],
          timestamp: ~N[2021-01-01 00:00:01]
        ),
        # Session 3 (US): Has pageview with neither matching
        build(:pageview,
          user_id: 3,
          pathname: "/checkout",
          country_code: "US",
          "meta.key": ["currency", "country"],
          "meta.value": ["USD", "US"],
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 3,
          pathname: "/checkout-no-props",
          country_code: "US",
          "meta.key": ["currency", "country"],
          "meta.value": ["USD", "US"],
          timestamp: ~N[2021-01-01 00:00:01]
        )
      ])

      # Query 1: Page goal with multiple custom props
      conn1 =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "visits", "events"],
          "dimensions" => ["visit:country"],
          "filters" => [["is", "event:goal", ["Visit /checkout"]]]
        })

      result1 = json_response(conn1, 200)["results"]

      # Query 2: Page goal without props + multiple separate prop filters
      conn2 =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "date_range" => "all",
          "metrics" => ["visitors", "visits", "events"],
          "dimensions" => ["visit:country"],
          "filters" => [
            ["is", "event:goal", ["Visit /checkout-no-props"]],
            ["is", "event:props:currency", ["EUR"]],
            ["is", "event:props:country", ["DE"]]
          ]
        })

      result2 = json_response(conn2, 200)["results"]

      # Both should return only DE (both props must match)
      assert result1 == [%{"dimensions" => ["DE"], "metrics" => [1, 1, 1]}]
      assert result2 == [%{"dimensions" => ["DE"], "metrics" => [1, 1, 1]}]
      assert result1 == result2
    end
  end
end
