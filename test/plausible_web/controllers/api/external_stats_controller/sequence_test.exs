defmodule PlausibleWeb.Api.ExternalStatsController.SequenceTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  #
  # Events table path ("next event after sequence" semantics)
  #
  # When querying with event-specific dimensions (event:page, event:name, etc.),
  # the sequence filter pins the result to the single immediate next event per
  # session after the sequence completed.
  #

  describe "sequence filter on events query" do
    test "returns next event after 2-step sequence", %{conn: conn, site: site} do
      populate_stats(site, [
        # Session 1: /pricing -> Signup -> /dashboard (sequence matches, next = /dashboard)
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/signup",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        # Session 2: /pricing only — no Signup, no match
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/other",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        # Session 3: Signup only — step 1 never satisfied
        build(:event,
          name: "Signup",
          pathname: "/signup",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/thanks",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:01:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/dashboard"], "metrics" => [1]}
             ]
    end

    test "returns next event after 3-step sequence", %{conn: conn, site: site} do
      populate_stats(site, [
        # Session 1: /a -> /b -> /c -> /result (full 3-step sequence, next = /result)
        build(:event,
          name: "pageview",
          pathname: "/a",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/b",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/c",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/result",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:03:00]
        ),
        # Session 2: /a -> /b only — misses step 3
        build(:event,
          name: "pageview",
          pathname: "/a",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/b",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/other",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:02:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            [
              "sequence",
              [
                ["is", "event:page", ["/a"]],
                ["is", "event:page", ["/b"]],
                ["is", "event:page", ["/c"]]
              ]
            ]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/result"], "metrics" => [1]}
             ]
    end

    test "order is enforced — steps in wrong order do not match", %{conn: conn, site: site} do
      populate_stats(site, [
        # Signup before /pricing — wrong order, should not match
        build(:event,
          name: "Signup",
          pathname: "/signup",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == []
    end

    test "sessions with no event after sequence are excluded", %{conn: conn, site: site} do
      populate_stats(site, [
        # Sequence completes but session ends — no next event to return
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/signup",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == []
    end

    test "returns IMMEDIATE next event, not any future event", %{conn: conn, site: site} do
      populate_stats(site, [
        # Session: /pricing -> Signup -> /step1 -> /step2
        # Next event after sequence is /step1, not /step2
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/signup",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/step1",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/step2",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:03:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      # Only /step1 (the immediate next), not /step2
      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/step1"], "metrics" => [1]}
             ]
    end

    test "multiple sessions each contribute their own next event", %{conn: conn, site: site} do
      populate_stats(site, [
        # User 1: /pricing -> Signup -> /dashboard
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/signup",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        # User 2: /pricing -> Signup -> /settings
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/signup",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/settings",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        # User 3: /pricing -> Signup -> /dashboard (same next page as user 1)
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "Signup",
          pathname: "/signup",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:02:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      results = json_response(conn, 200)["results"]
      assert length(results) == 2
      assert %{"dimensions" => ["/dashboard"], "metrics" => [2]} in results
      assert %{"dimensions" => ["/settings"], "metrics" => [1]} in results
    end

    test "single-step sequence returns next event", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "pageview",
          pathname: "/landing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/next",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        # User 2: same landing page but different next page
        build(:event,
          name: "pageview",
          pathname: "/landing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/other-next",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:01:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [["sequence", [["is", "event:page", ["/landing"]]]]]
        })

      results = json_response(conn, 200)["results"]
      assert length(results) == 2
      assert %{"dimensions" => ["/next"], "metrics" => [1]} in results
      assert %{"dimensions" => ["/other-next"], "metrics" => [1]} in results
    end

    test "step matching on event:name works", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event, name: "AddToCart", user_id: 1, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Checkout", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/confirmation",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        # No AddToCart -> Checkout sequence
        build(:event, name: "Checkout", user_id: 2, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event,
          name: "pageview",
          pathname: "/confirmation",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:01:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            [
              "sequence",
              [["is", "event:name", ["AddToCart"]], ["is", "event:name", ["Checkout"]]]
            ]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/confirmation"], "metrics" => [1]}
             ]
    end

    test "step with `and` operator matches compound conditions on the same event", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        # Step 1: pageview on /pricing AND step 2: Signup
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/done",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        # /other pageview then Signup — step 1 not satisfied (wrong page)
        build(:event,
          name: "pageview",
          pathname: "/other",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 2, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/done",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:02:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            [
              "sequence",
              [
                ["and", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["pageview"]]]],
                ["is", "event:name", ["Signup"]]
              ]
            ]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/done"], "metrics" => [1]}
             ]
    end

    test "sequence does not cross session boundaries", %{conn: conn, site: site} do
      populate_stats(site, [
        # User 1 session 1: /pricing (step 1 satisfied)
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        # User 1 session 2 (31+ minutes later): Signup (should NOT chain with previous session's step 1)
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 01:00:00]),
        build(:event,
          name: "pageview",
          pathname: "/next",
          user_id: 1,
          timestamp: ~N[2021-01-01 01:01:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == []
    end

    test "sequence with event:name dimension works", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event, name: "Purchase", user_id: 1, timestamp: ~N[2021-01-01 00:02:00]),
        # No /pricing first
        build(:event, name: "Signup", user_id: 2, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event, name: "Purchase", user_id: 2, timestamp: ~N[2021-01-01 00:01:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:name"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Purchase"], "metrics" => [1]}
             ]
    end
  end

  #
  # Sessions table path (session membership semantics)
  #
  # When querying with non-event dimensions (visit:source, visit:country, etc.)
  # or no dimensions at all, the sequence filter restricts to sessions where
  # the sequence occurred — regardless of whether there is a next event.
  #

  describe "sequence filter on sessions query" do
    test "restricts sessions to those where sequence occurred", %{conn: conn, site: site} do
      populate_stats(site, [
        # Session 1: sequence completed — counts
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        # Session 2: /pricing only — no Signup, no match
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Direct / None"], "metrics" => [1]}
             ]
    end

    test "counts session even when there is no next event after the sequence", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        # Sequence completes but session ends — sessions query should still count it
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Direct / None"], "metrics" => [1]}
             ]
    end

    test "session membership is not affected by events after the sequence", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/settings",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:03:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      # Only 1 visitor, not duplicated for each subsequent event
      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Direct / None"], "metrics" => [1]}
             ]
    end

    test "order is enforced on sessions query", %{conn: conn, site: site} do
      populate_stats(site, [
        # Signup before /pricing — wrong order
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:00:00]),
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == []
    end

    test "3-step sequence on sessions query", %{conn: conn, site: site} do
      populate_stats(site, [
        # Full 3-step sequence — counts
        build(:event,
          name: "pageview",
          pathname: "/a",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/b",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/c",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        # Only 2 out of 3 steps — no match
        build(:event,
          name: "pageview",
          pathname: "/a",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/b",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:01:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:source"],
          "filters" => [
            [
              "sequence",
              [
                ["is", "event:page", ["/a"]],
                ["is", "event:page", ["/b"]],
                ["is", "event:page", ["/c"]]
              ]
            ]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["Direct / None"], "metrics" => [1]}
             ]
    end

    test "aggregate visitors with no dimensions", %{conn: conn, site: site} do
      populate_stats(site, [
        # User 1: completes sequence
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        # User 2: completes sequence
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 2, timestamp: ~N[2021-01-01 00:01:00]),
        # User 3: no sequence
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => [], "metrics" => [2]}
             ]
    end

    test "visits metric counts sessions with sequence", %{conn: conn, site: site} do
      populate_stats(site, [
        # User 1: completes sequence
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        # User 2: no sequence
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "visits"],
          "date_range" => "all",
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => [], "metrics" => [1, 1]}
             ]
    end

    test "multiple users completing sequence are all counted", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 2, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 3, timestamp: ~N[2021-01-01 00:01:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"dimensions" => [], "metrics" => [3]}]
    end

    test "sequence steps satisfied multiple times in one session count visitor once", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        # User 1 visits /pricing -> Signup -> /pricing -> Signup twice in same session
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:03:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"dimensions" => [], "metrics" => [1]}]
    end

    test "sequence combined with a top-level event filter", %{conn: conn, site: site} do
      populate_stats(site, [
        # User 1: /pricing -> Signup -> /dashboard (sequence + has dashboard visit)
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        # User 2: /pricing -> Signup but no /dashboard
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 2, timestamp: ~N[2021-01-01 00:01:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]],
            ["is", "event:page", ["/dashboard"]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"dimensions" => [], "metrics" => [1]}]
    end

    test "sequence does not cross session boundaries on sessions query", %{conn: conn, site: site} do
      populate_stats(site, [
        # User 1 session 1: /pricing (step 1)
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        # User 1 session 2 (new session, 31+ minutes later): Signup — should NOT chain
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 01:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"dimensions" => [], "metrics" => [0]}]
    end
  end

  #
  # Validation errors
  #

  describe "sequence filter validation" do
    test "rejects sequence with visit dimension in steps", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["sequence", [["is", "visit:source", ["Google"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 400)["error"] =~
               "Behavioral filters (has_done, has_not_done, sequence) can only be used with event dimension filters"
    end

    test "rejects sequence nested inside has_done", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [
              "has_done",
              ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
            ]
          ]
        })

      assert json_response(conn, 400)["error"] =~
               "Behavioral filters (has_done, has_not_done, sequence) cannot be nested"
    end

    test "rejects sequence wrapped in not", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [
              "not",
              ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
            ]
          ]
        })

      assert json_response(conn, 400)["error"] =~
               "sequence filters cannot be wrapped in not"
    end

    test "rejects has_done nested inside sequence steps", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [
              "sequence",
              [
                ["has_done", ["is", "event:page", ["/pricing"]]],
                ["is", "event:name", ["Signup"]]
              ]
            ]
          ]
        })

      assert json_response(conn, 400)["error"] =~
               "Behavioral filters (has_done, has_not_done, sequence) cannot be nested"
    end

    test "rejects sequence nested inside sequence", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [
              "sequence",
              [
                ["sequence", [["is", "event:page", ["/a"]], ["is", "event:page", ["/b"]]]],
                ["is", "event:name", ["Signup"]]
              ]
            ]
          ]
        })

      assert json_response(conn, 400)["error"] =~
               "Behavioral filters (has_done, has_not_done, sequence) cannot be nested"
    end

    test "rejects sequence with non-list steps (schema validation)", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [["sequence", "not-a-list"]]
        })

      assert json_response(conn, 400)["error"] =~ "Invalid filter"
    end
  end

  #
  # Edge cases and specific scenarios
  #

  describe "sequence filter edge cases" do
    test "step 1 event that also satisfies step 2 does not cause self-join match", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        # Single /pricing event — step 2 (also /pricing) must come AFTER step 1
        # so this single event should not match both steps
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/next",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        # Two /pricing events — step 1 = first, step 2 = second, next = /done
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:01:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/done",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:02:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:page", ["/pricing"]]]]
          ]
        })

      # Only user 2 matches (two /pricing events), next = /done
      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/done"], "metrics" => [1]}
             ]
    end

    test "sequence with multiple possible step1 anchors uses the earliest one", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        # Two /pricing events, Signup comes after the first
        # The earliest /pricing is the anchor, Signup is the step 2, /done is next
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/done",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:03:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      # Next event after Signup (first completion) is /pricing (00:02), not /done
      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/pricing"], "metrics" => [1]}
             ]
    end

    test "sequence with or operator in step", %{conn: conn, site: site} do
      populate_stats(site, [
        # Step 1: /pricing OR /plans, step 2: Signup
        build(:event,
          name: "pageview",
          pathname: "/plans",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 2, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:02:00]
        ),
        # /other -> Signup — step 1 not satisfied
        build(:event,
          name: "pageview",
          pathname: "/other",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 3, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event,
          name: "pageview",
          pathname: "/dashboard",
          user_id: 3,
          timestamp: ~N[2021-01-01 00:02:00]
        )
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "filters" => [
            [
              "sequence",
              [
                ["or", [["is", "event:page", ["/pricing"]], ["is", "event:page", ["/plans"]]]],
                ["is", "event:name", ["Signup"]]
              ]
            ]
          ]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/dashboard"], "metrics" => [2]}
             ]
    end

    test "sequence combined with has_done at top level", %{conn: conn, site: site} do
      populate_stats(site, [
        # User 1: /pricing -> Signup AND has done Purchase at some point
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        build(:event, name: "Purchase", user_id: 1, timestamp: ~N[2021-01-01 00:02:00]),
        # User 2: /pricing -> Signup but no Purchase
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 2, timestamp: ~N[2021-01-01 00:01:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]],
            ["has_done", ["is", "event:name", ["Purchase"]]]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"dimensions" => [], "metrics" => [1]}]
    end

    test "sequence with event:props step filter", %{conn: conn, site: site} do
      populate_stats(site, [
        # User 1: FileDownload with type=pdf -> Signup
        build(:event,
          name: "FileDownload",
          "meta.key": ["type"],
          "meta.value": ["pdf"],
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00]),
        # User 2: FileDownload with type=doc (not pdf) -> Signup — step 1 not satisfied
        build(:event,
          name: "FileDownload",
          "meta.key": ["type"],
          "meta.value": ["doc"],
          user_id: 2,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 2, timestamp: ~N[2021-01-01 00:01:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [
              "sequence",
              [
                [
                  "and",
                  [
                    ["is", "event:name", ["FileDownload"]],
                    ["is", "event:props:type", ["pdf"]]
                  ]
                ],
                ["is", "event:name", ["Signup"]]
              ]
            ]
          ]
        })

      assert json_response(conn, 200)["results"] == [%{"dimensions" => [], "metrics" => [1]}]
    end

    test "returns imports warning when sequence filter is used with imported data", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "pageview",
          pathname: "/pricing",
          user_id: 1,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:event, name: "Signup", user_id: 1, timestamp: ~N[2021-01-01 00:01:00])
      ])

      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:imported_visitors, date: ~D[2021-01-01])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "include" => %{"imports" => true},
          "filters" => [
            ["sequence", [["is", "event:page", ["/pricing"]], ["is", "event:name", ["Signup"]]]]
          ]
        })

      assert json_response(conn, 200)["meta"]["imports_warning"] != nil
    end
  end
end
