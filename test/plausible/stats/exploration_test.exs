defmodule Plausible.Stats.ExplorationTest do
  use Plausible.DataCase
  use Plausible

  on_ee do
    alias Plausible.Stats.Exploration
    alias Plausible.Stats.QueryBuilder

    setup do
      site = new_site()

      now = DateTime.utc_now()

      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          pathname: "/home",
          browser: "Chrome",
          timestamp: DateTime.shift(now, minute: -300)
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/login",
          browser: "Chrome",
          timestamp: DateTime.shift(now, minute: -270)
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/home",
          browser: "Chrome",
          timestamp: DateTime.shift(now, minute: -30)
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/login",
          browser: "Chrome",
          timestamp: DateTime.shift(now, minute: -25)
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/logout",
          browser: "Chrome",
          timestamp: DateTime.shift(now, minute: -20)
        ),
        build(:pageview,
          user_id: 124,
          pathname: "/home",
          browser: "Firefox",
          timestamp: DateTime.shift(now, minute: -30)
        ),
        build(:pageview,
          user_id: 124,
          pathname: "/login",
          browser: "Firefox",
          timestamp: DateTime.shift(now, minute: -25)
        ),
        build(:pageview,
          user_id: 124,
          pathname: "/docs",
          browser: "Firefox",
          timestamp: DateTime.shift(now, minute: -20)
        ),
        build(:pageview,
          user_id: 124,
          pathname: "/logout",
          browser: "Firefox",
          timestamp: DateTime.shift(now, minute: -15)
        )
      ])

      {:ok, site: site}
    end

    describe "journey_funnel" do
      test "queries 3-step journey", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/logout"}
        ]

        assert {:ok, [step1, step2, step3]} = Exploration.journey_funnel(query, journey)

        assert step1.step.pathname == "/home"
        assert step1.visitors == 2
        assert step1.dropoff == 0
        assert step1.dropoff_percentage == "0"
        assert step1.conversion_rate == "100"
        assert step1.conversion_rate_step == "0"
        assert step2.step.pathname == "/login"
        assert step2.visitors == 2
        assert step2.dropoff == 0
        assert step2.dropoff_percentage == "0"
        assert step2.conversion_rate == "100"
        assert step2.conversion_rate_step == "100"
        assert step3.step.pathname == "/logout"
        assert step3.visitors == 1
        assert step3.dropoff == 1
        assert step3.dropoff_percentage == "50"
        assert step3.conversion_rate == "50"
        assert step3.conversion_rate_step == "50"
      end

      test "returns labels" do
        site = new_site()

        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:event,
            user_id: 123,
            name: "Signup",
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -280)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/activate",
            timestamp: DateTime.shift(now, minute: -270)
          ),
          build(:event,
            user_id: 123,
            name: "Create site",
            pathname: "/sites/new",
            timestamp: DateTime.shift(now, minute: -260)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/register"},
          %Exploration.Journey.Step{name: "Signup", pathname: "/register"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/activate"},
          %Exploration.Journey.Step{name: "Create site", pathname: "/sites/new"}
        ]

        assert {:ok, [step1, step2, step3, step4]} = Exploration.journey_funnel(query, journey)

        assert step1.step.label == "/register"
        assert step2.step.label == "Signup /register"
        assert step3.step.label == "/activate"
        assert step4.step.label == "Create site /sites/new"
      end

      test "respects filters in the query", %{site: site} do
        query =
          QueryBuilder.build!(site,
            input_date_range: :all,
            filters: [[:is, "visit:browser", ["Firefox"]]]
          )

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/logout"}
        ]

        assert {:ok, [step1, step2, step3]} = Exploration.journey_funnel(query, journey)

        assert step1.step.pathname == "/home"
        assert step1.visitors == 1
        assert step1.dropoff == 0
        assert step1.dropoff_percentage == "0"
        assert step1.conversion_rate == "100"
        assert step1.conversion_rate_step == "0"
        assert step2.step.pathname == "/login"
        assert step2.visitors == 1
        assert step2.dropoff == 0
        assert step2.dropoff_percentage == "0"
        assert step2.conversion_rate == "100"
        assert step2.conversion_rate_step == "100"
        assert step3.step.pathname == "/logout"
        assert step3.visitors == 0
        assert step3.dropoff == 1
        assert step3.dropoff_percentage == "100"
        assert step3.conversion_rate == "0"
        assert step3.conversion_rate_step == "0"
      end

      test "returns error on empty journey", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:error, :empty_journey} = Exploration.journey_funnel(query, [])
      end

      test "returns error on too long journey", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey =
          Enum.map(1..21, fn idx ->
            %Exploration.Journey.Step{name: "pageview", pathname: "/page#{idx}"}
          end)

        assert {:error, :journey_too_long} = Exploration.journey_funnel(query, journey)
      end

      test "supports backward journey funnel", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/logout"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"}
        ]

        assert {:ok, [step1, step2, step3]} =
                 Exploration.journey_funnel(query, journey, :backward)

        assert step1.step.pathname == "/logout"
        assert step1.visitors == 2
        assert step1.dropoff == 0
        assert step1.dropoff_percentage == "0"
        assert step1.conversion_rate == "100"
        assert step1.conversion_rate_step == "0"
        assert step2.step.pathname == "/login"
        assert step2.visitors == 1
        assert step2.dropoff == 1
        assert step2.dropoff_percentage == "50"
        assert step2.conversion_rate == "50"
        assert step2.conversion_rate_step == "50"
        assert step3.step.pathname == "/home"
        assert step3.visitors == 1
        assert step3.dropoff == 0
        assert step3.dropoff_percentage == "0"
        assert step3.conversion_rate == "50"
        assert step3.conversion_rate_step == "100"
      end
    end

    describe "interesting_funnel" do
      test "builds a funnel starting with the most visited step", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [step1, step2, step3, step4]} = Exploration.interesting_funnel(query)

        assert step1.step.pathname == "/home"
        assert step1.visitors == 2

        assert step2.step.pathname == "/login"
        assert step2.visitors == 2

        assert step3.step.pathname == "/docs"
        assert step3.visitors == 1

        assert step4.step.pathname == "/logout"
        assert step4.visitors == 1
      end

      test "limits the funnel to max_steps", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [step1, step2]} = Exploration.interesting_funnel(query, max_steps: 2)

        assert step1.step.pathname == "/home"
        assert step2.step.pathname == "/login"
      end

      test "returns error when no events exist" do
        empty_site = new_site()
        query = QueryBuilder.build!(empty_site, input_date_range: :all)

        assert {:error, :not_found} = Exploration.interesting_funnel(query)
      end

      test "stops when no more unseen steps are available" do
        site = new_site()
        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/only-page",
            timestamp: DateTime.shift(now, minute: -30)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [step1]} = Exploration.interesting_funnel(query, max_steps: 6)

        assert step1.step.pathname == "/only-page"
        assert step1.visitors == 1
      end

      test "respects query filters", %{site: site} do
        query =
          QueryBuilder.build!(site,
            input_date_range: :all,
            filters: [[:is, "visit:browser", ["Firefox"]]]
          )

        assert {:ok, funnel} = Exploration.interesting_funnel(query)

        pathnames = Enum.map(funnel, & &1.step.pathname)
        assert pathnames == ["/docs", "/logout"]
      end

      test "does not revisit already-seen steps in a cycle" do
        site = new_site()
        now = DateTime.utc_now()

        populate_stats(site, [
          # user 123
          build(:pageview,
            user_id: 123,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/b",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -30)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/b",
            timestamp: DateTime.shift(now, minute: -20)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/c",
            timestamp: DateTime.shift(now, minute: -10)
          ),
          # user 124
          build(:pageview,
            user_id: 124,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/b",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/c",
            timestamp: DateTime.shift(now, minute: -30)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, funnel} = Exploration.interesting_funnel(query)

        pathnames = Enum.map(funnel, & &1.step.pathname)
        assert pathnames == ["/a", "/b", "/c"]
      end
    end

    describe "next_steps" do
      test "suggests the next step for a 2-step journey", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        assert {:ok, [next_step1, next_step2, next_step3]} =
                 Exploration.next_steps(query, journey)

        assert next_step1.step.label == "/docs"
        assert next_step1.step.pathname == "/docs"
        assert next_step1.visitors == 1
        assert next_step2.step.label == "/home"
        assert next_step2.step.pathname == "/home"
        assert next_step2.visitors == 1
        assert next_step3.step.label == "/logout"
        assert next_step3.step.pathname == "/logout"
        assert next_step3.visitors == 1
      end

      test "respects max_candidates", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        assert {:ok, [%{step: %{pathname: "/docs"}}]} =
                 Exploration.next_steps(query, journey, max_candidates: 1)
      end

      test "returns error on too long journey", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey =
          Enum.map(1..20, fn idx ->
            %Exploration.Journey.Step{name: "pageview", pathname: "/page#{idx}"}
          end)

        assert {:error, :journey_too_long} = Exploration.next_steps(query, journey)
      end

      test "suggests the first step in the journey", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [next_step1, next_step2, next_step3, next_step4]} =
                 Exploration.next_steps(query, [])

        assert next_step1.step.pathname == "/home"
        assert next_step1.visitors == 2
        assert next_step2.step.pathname == "/login"
        assert next_step2.visitors == 2
        assert next_step3.step.pathname == "/logout"
        assert next_step3.visitors == 2
        assert next_step4.step.pathname == "/docs"
        assert next_step4.visitors == 1
      end

      test "respects filters in the query", %{site: site} do
        query =
          QueryBuilder.build!(site,
            input_date_range: :all,
            filters: [[:is, "visit:browser", ["Firefox"]]]
          )

        assert {:ok, [next_step1, next_step2, next_step3, next_step4]} =
                 Exploration.next_steps(query, [])

        assert next_step1.step.pathname == "/docs"
        assert next_step1.visitors == 1
        assert next_step2.step.pathname == "/home"
        assert next_step2.visitors == 1
        assert next_step3.step.pathname == "/login"
        assert next_step3.visitors == 1
        assert next_step4.step.pathname == "/logout"
        assert next_step4.visitors == 1
      end

      test "allows to filter the next step suggestions", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        assert {:ok, [next_step]} = Exploration.next_steps(query, journey, search_term: "doc")

        assert next_step.step.pathname == "/docs"
        assert next_step.visitors == 1
      end

      test "includes root path (/) in suggestions" do
        site = new_site()

        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 122,
            pathname: "/",
            timestamp: DateTime.shift(now, minute: -320)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/",
            timestamp: DateTime.shift(now, minute: -320)
          ),
          build(:event,
            user_id: 123,
            name: "Signup",
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -300)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [next_step1, next_step2]} = Exploration.next_steps(query, [])

        assert next_step1.step.label == "/"
        assert next_step1.visitors == 2

        assert next_step2.step.label == "Signup /register"
        assert next_step2.visitors == 1
      end

      test "allows to filter according to how label is rendered" do
        site = new_site()

        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -320)
          ),
          build(:event,
            user_id: 123,
            name: "Signup",
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/sites/new",
            timestamp: DateTime.shift(now, minute: -270)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"}
        ]

        assert {:ok, [next_step]} =
                 Exploration.next_steps(query, journey, search_term: "up /regi")

        assert next_step.step.label == "Signup /register"
        assert next_step.step.name == "Signup"
        assert next_step.step.pathname == "/register"
        assert next_step.visitors == 1
      end

      test "supports backward exploration", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/logout"}
        ]

        assert {:ok, [next_step1, next_step2]} =
                 Exploration.next_steps(query, journey, direction: :backward)

        assert next_step1.visitors == 1
        assert next_step2.step.pathname == "/login"
        assert next_step2.visitors == 1
      end

      test "does not suggest the same path/pathname as in previous step (regression test)" do
        site = new_site()

        now = DateTime.utc_now()

        ago = fn ms -> DateTime.shift(now, minute: -1 * ms) end

        # The issue manifested in some very specific combinations of events with occurrences
        # of different path/pathname combinations, some of them with identical timestamp.
        #
        # The cause was inconsistent ordering between `q_pairs` and `q_steps` in `steps_query`.
        #
        populate_stats(site, [
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(100)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(100)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(99)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(98)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(97)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(96)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(95)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(94)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(93)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(92)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(91)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(90)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(89)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(88)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(87)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(87)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(86)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(85)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(84)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(83)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(82)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(81)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(80)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(79)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(78)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(77)),
          build(:pageview, user_id: 123, pathname: "/:dashboard", timestamp: ago.(76))
        ])

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/sites"}
        ]

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok,
                [
                  %{step: %{pathname: "/:dashboard"}}
                ]} =
                 Exploration.next_steps(query, journey, search_term: "", direction: :forward)

        assert {:ok,
                [
                  %{step: %{pathname: "/:dashboard"}}
                ]} =
                 Exploration.next_steps(query, journey, search_term: "", direction: :backward)
      end

      test "treats identical sequence of events as a single step" do
        site = new_site()

        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -270)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -30)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -25)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -24)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -23)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/logout",
            timestamp: DateTime.shift(now, minute: -20)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -30)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -25)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/docs",
            timestamp: DateTime.shift(now, minute: -20)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/docs",
            timestamp: DateTime.shift(now, minute: -19)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/logout",
            timestamp: DateTime.shift(now, minute: -15)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        assert {:ok, [next_step1, next_step2, next_step3]} =
                 Exploration.next_steps(query, journey)

        assert next_step1.step.pathname == "/docs"
        assert next_step1.visitors == 1
        assert next_step2.step.pathname == "/home"
        assert next_step2.visitors == 1
        assert next_step3.step.pathname == "/logout"
        assert next_step3.visitors == 1

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/docs"}
        ]

        assert {:ok, [next_step]} = Exploration.next_steps(query, journey)

        assert next_step.step.pathname == "/logout"
        assert next_step.visitors == 1
      end

      test "treats identical sequence of events as a single step when searching backwards" do
        site = new_site()

        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -270)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -30)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -25)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -24)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -23)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/logout",
            timestamp: DateTime.shift(now, minute: -20)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/logout"}
        ]

        assert {:ok, [next_step]} = Exploration.next_steps(query, journey, direction: :backward)

        assert next_step.step.pathname == "/login"
        assert next_step.visitors == 1
      end

      test "consecutive events from different users are not merged" do
        now = DateTime.utc_now()

        site = new_site()

        populate_stats(site, [
          build(:pageview,
            user_id: 124,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -30)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -25)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -24)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -23)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/logout",
            timestamp: DateTime.shift(now, minute: -20)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/logout",
            timestamp: DateTime.shift(now, minute: -20)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [next_step1, next_step2, next_step3]} = Exploration.next_steps(query, [])

        assert next_step1.step.pathname == "/home"
        assert next_step1.visitors == 2
        assert next_step2.step.pathname == "/login"
        assert next_step2.visitors == 2
        assert next_step3.step.pathname == "/logout"
        assert next_step3.visitors == 2

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"}
        ]

        assert {:ok, [next_step]} = Exploration.next_steps(query, journey)

        assert next_step.step.pathname == "/login"
        assert next_step.visitors == 2

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        assert {:ok, [next_step]} = Exploration.next_steps(query, journey)

        assert next_step.step.pathname == "/logout"
        assert next_step.visitors == 2
      end
    end

    describe "implicit wildcard pathnames" do
      setup do
        now = DateTime.utc_now()
        site = new_site()

        populate_stats(site, [
          build(:pageview,
            user_id: 122,
            pathname: "/aa",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 126,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 127,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/a/b",
            timestamp: DateTime.shift(now, minute: -270)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/a/b",
            timestamp: DateTime.shift(now, minute: -270)
          ),
          build(:pageview,
            user_id: 126,
            pathname: "/a/d",
            timestamp: DateTime.shift(now, minute: -270)
          ),
          build(:pageview,
            user_id: 127,
            pathname: "/a/d",
            timestamp: DateTime.shift(now, minute: -270)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/a/b/c",
            timestamp: DateTime.shift(now, minute: -240)
          ),
          build(:pageview,
            user_id: 128,
            pathname: "/a/b/c",
            timestamp: DateTime.shift(now, minute: -240)
          )
        ])

        {:ok, site: site}
      end

      test "implicit wildcard path visitors computation is correct and consistent between next_step and journey_funnel",
           %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        result = Exploration.next_steps(query, [])

        assert {:ok,
                [
                  %{
                    step: %{label: "/a", includes_subpaths: true, subpaths_count: 4},
                    visitors: 6
                  },
                  %{step: %{label: "/a", includes_subpaths: false}, visitors: 5},
                  %{
                    step: %{label: "/a/b", includes_subpaths: true, subpaths_count: 2},
                    visitors: 3
                  },
                  %{step: %{label: "/a/b", includes_subpaths: false}, visitors: 2},
                  %{step: %{label: "/a/b/c"}, visitors: 2},
                  %{step: %{label: "/a/d"}, visitors: 2},
                  %{step: %{label: "/aa"}, visitors: 1}
                ]} = result

        journey = [
          %Exploration.Journey.Step{
            name: "pageview",
            pathname: "/a",
            includes_subpaths: true,
            subpaths_count: 4
          }
        ]

        assert {:ok, [step1]} = Exploration.journey_funnel(query, journey)

        assert step1.step.label == "/a"
        assert step1.step.includes_subpaths == true
        assert step1.visitors == 6
      end

      test "implicit wildcard paths are not returned in suggestions when explicitly disabled", %{
        site: site
      } do
        query = QueryBuilder.build!(site, input_date_range: :all)

        result = Exploration.next_steps(query, [], include_wildcard?: false)

        assert {:ok,
                [
                  %{step: %{label: "/a", includes_subpaths: false}, visitors: 5},
                  %{step: %{label: "/a/b", includes_subpaths: false}, visitors: 2},
                  %{step: %{label: "/a/b/c"}, visitors: 2},
                  %{step: %{label: "/a/d"}, visitors: 2},
                  %{step: %{label: "/aa"}, visitors: 1}
                ]} = result
      end
    end
  end
end
