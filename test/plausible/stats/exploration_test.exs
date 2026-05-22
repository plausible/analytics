defmodule Plausible.Stats.ExplorationTest do
  use Plausible.DataCase
  use Plausible

  on_ee do
    alias Plausible.Stats.Exploration
    alias Plausible.Stats.QueryBuilder

    @journey_end_event Exploration.Journey.Step.journey_end_event()
    @journey_end_label Exploration.Journey.Step.journey_end_label()

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
          %Exploration.Journey.Step{name: "Signup"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/activate"},
          %Exploration.Journey.Step{name: "Create site"}
        ]

        assert {:ok, [step1, step2, step3, step4]} = Exploration.journey_funnel(query, journey)

        assert step1.step.label == "/register"
        assert step2.step.label == "Signup"
        assert step3.step.label == "/activate"
        assert step4.step.label == "Create site"
      end

      test "handles journey end event step" do
        site = new_site()
        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -30)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -20)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/dashboard",
            timestamp: DateTime.shift(now, minute: -10)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/dashboard",
            timestamp: DateTime.shift(now, minute: -30)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"},
          %Exploration.Journey.Step{name: Exploration.Journey.Step.journey_end_event()}
        ]

        assert {:ok, [_step1, _step2, step3]} = Exploration.journey_funnel(query, journey)

        assert step3.step.label == Exploration.Journey.Step.journey_end_label()
        assert step3.step.name == Exploration.Journey.Step.journey_end_event()
        assert step3.visitors == 1
        assert step3.dropoff == 2
        assert step3.dropoff_percentage == "66.67"
        assert step3.conversion_rate == "33.33"
        assert step3.conversion_rate_step == "33.33"
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

      test "excludes revenue events from journey funnel steps" do
        site = new_site()
        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:event,
            user_id: 123,
            name: "Purchase",
            pathname: "/checkout",
            revenue_reporting_amount: Decimal.new("100"),
            revenue_reporting_currency: "USD",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/thank-you",
            timestamp: DateTime.shift(now, minute: -30)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/thank-you"}
        ]

        assert {:ok, [step1, step2]} = Exploration.journey_funnel(query, journey)

        # Revenue event is skipped
        assert step1.step.pathname == "/home"
        assert step1.visitors == 1
        assert step2.step.pathname == "/thank-you"
        assert step2.visitors == 1
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

      test "handles goal with a pattern" do
        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/site*", is_goal: true},
          %Exploration.Journey.Step{name: "pageview", pathname: "/dashboard"}
        ]

        site = new_site()
        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/sites",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/dashboard",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/sites/settings",
            timestamp: DateTime.shift(now, minute: -50)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [step1, step2]} = Exploration.journey_funnel(query, journey)

        assert step1.step.pathname == "/site*"
        assert step1.visitors == 2
        assert step1.dropoff == 0
        assert step1.dropoff_percentage == "0"
        assert step1.conversion_rate == "100"
        assert step1.conversion_rate_step == "0"
        assert step2.step.pathname == "/dashboard"
        assert step2.visitors == 1
        assert step2.dropoff == 1
        assert step2.dropoff_percentage == "50"
        assert step2.conversion_rate == "50"
        assert step2.conversion_rate_step == "50"
      end

      test "handles wildcard step properly" do
        journey = [
          %Exploration.Journey.Step{
            name: "pageview",
            pathname: "/sites",
            includes_subpaths: true,
            subpaths_count: 2,
            is_goal: true
          },
          %Exploration.Journey.Step{name: "pageview", pathname: "/dashboard"}
        ]

        site = new_site()
        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/sites",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/dashboard",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/sites/settings",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/sites-are-cool",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 126,
            pathname: "/sites/",
            timestamp: DateTime.shift(now, minute: -50)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [step1, step2]} = Exploration.journey_funnel(query, journey)

        assert step1.step.pathname == "/sites"
        assert step1.visitors == 3
        assert step1.dropoff == 0
        assert step1.dropoff_percentage == "0"
        assert step1.conversion_rate == "100"
        assert step1.conversion_rate_step == "0"
        assert step2.step.pathname == "/dashboard"
        assert step2.visitors == 1
        assert step2.dropoff == 2
        assert step2.dropoff_percentage == "66.67"
        assert step2.conversion_rate == "33.33"
        assert step2.conversion_rate_step == "33.33"
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
                 Exploration.next_steps(site, query, journey)

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

      test "excludes revenue events from next step suggestions" do
        site = new_site()
        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:event,
            user_id: 123,
            name: "Purchase",
            pathname: "/checkout",
            revenue_reporting_amount: Decimal.new("100"),
            revenue_reporting_currency: "USD",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/thank-you",
            timestamp: DateTime.shift(now, minute: -30)
          )
        ])

        {:ok, _} =
          Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "USD"})

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, steps} = Exploration.next_steps(site, query, [])

        refute "Purchase" in Enum.map(steps, & &1.step.name)
        refute "/checkout" in Enum.map(steps, & &1.step.pathname)

        journey = [%Exploration.Journey.Step{name: "pageview", pathname: "/home"}]
        assert {:ok, [next_step]} = Exploration.next_steps(site, query, journey)
        assert next_step.step.pathname == "/thank-you"
        assert next_step.step.name == "pageview"
      end

      test "respects max_candidates", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        assert {:ok, [%{step: %{pathname: "/docs"}}]} =
                 Exploration.next_steps(site, query, journey, max_candidates: 1)
      end

      test "returns error on too long journey", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey =
          Enum.map(1..20, fn idx ->
            %Exploration.Journey.Step{name: "pageview", pathname: "/page#{idx}"}
          end)

        assert {:error, :journey_too_long} = Exploration.next_steps(site, query, journey)
      end

      test "suggests the first step in the journey", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, [next_step1, next_step2, next_step3, next_step4]} =
                 Exploration.next_steps(site, query, [])

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
                 Exploration.next_steps(site, query, [])

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

        assert {:ok, [next_step]} =
                 Exploration.next_steps(site, query, journey, search_term: "doc")

        assert next_step.step.pathname == "/docs"
        assert next_step.visitors == 1
      end

      test "allows to filter by journey end event label" do
        site = new_site()
        now = DateTime.utc_now()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -30)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -20)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/dashboard",
            timestamp: DateTime.shift(now, minute: -10)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -50)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/login",
            timestamp: DateTime.shift(now, minute: -40)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/dashboard",
            timestamp: DateTime.shift(now, minute: -30)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        assert {:ok, [next_step]} =
                 Exploration.next_steps(site, query, journey, search_term: "no further")

        assert next_step.step.label == "No further action"
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

        assert {:ok, [next_step1, next_step2]} = Exploration.next_steps(site, query, [])

        assert next_step1.step.label == "/"
        assert next_step1.visitors == 2

        assert next_step2.step.label == "Signup"
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
                 Exploration.next_steps(site, query, journey, search_term: "up")

        assert next_step.step.label == "Signup"
        assert next_step.step.name == "Signup"
        assert next_step.step.pathname == ""
        assert next_step.visitors == 1
      end

      test "supports backward exploration", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/logout"}
        ]

        assert {:ok, [next_step1, next_step2]} =
                 Exploration.next_steps(site, query, journey, direction: :backward)

        assert next_step1.visitors == 1
        assert next_step2.step.pathname == "/login"
        assert next_step2.visitors == 1
      end

      test "there can be multiple journey suggestions for a single user/session" do
        site = new_site()

        now = DateTime.utc_now()

        ago = fn ms -> DateTime.shift(now, minute: -1 * ms) end

        populate_stats(site, [
          build(:pageview, user_id: 123, pathname: "/home", timestamp: ago.(100)),
          build(:pageview, user_id: 123, pathname: "/login", timestamp: ago.(99)),
          build(:pageview, user_id: 123, pathname: "/dashboard", timestamp: ago.(98)),
          build(:pageview, user_id: 123, pathname: "/home", timestamp: ago.(97)),
          build(:pageview, user_id: 123, pathname: "/login", timestamp: ago.(96)),
          build(:pageview, user_id: 123, pathname: "/sites", timestamp: ago.(95))
        ])

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok,
                [
                  %{step: %{pathname: "/dashboard"}, visitors: 1},
                  %{step: %{pathname: "/sites"}, visitors: 1}
                ]} =
                 Exploration.next_steps(site, query, journey,
                   search_term: "",
                   direction: :forward
                 )
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
                 Exploration.next_steps(site, query, journey,
                   search_term: "",
                   direction: :forward
                 )

        assert {:ok,
                [
                  %{step: %{name: @journey_end_event}},
                  %{step: %{pathname: "/:dashboard"}}
                ]} =
                 Exploration.next_steps(site, query, journey,
                   search_term: "",
                   direction: :backward
                 )
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
                 Exploration.next_steps(site, query, journey)

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

        assert {:ok, [next_step]} = Exploration.next_steps(site, query, journey)

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

        assert {:ok, [next_step]} =
                 Exploration.next_steps(site, query, journey, direction: :backward)

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

        assert {:ok, [next_step1, next_step2, next_step3]} =
                 Exploration.next_steps(site, query, [])

        assert next_step1.step.pathname == "/home"
        assert next_step1.visitors == 2
        assert next_step2.step.pathname == "/login"
        assert next_step2.visitors == 2
        assert next_step3.step.pathname == "/logout"
        assert next_step3.visitors == 2

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"}
        ]

        assert {:ok, [next_step]} = Exploration.next_steps(site, query, journey)

        assert next_step.step.pathname == "/login"
        assert next_step.visitors == 2

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
          %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
        ]

        assert {:ok, [next_step]} = Exploration.next_steps(site, query, journey)

        assert next_step.step.pathname == "/logout"
        assert next_step.visitors == 2
      end

      test "considers existing goals in the listing" do
        now = DateTime.utc_now()
        site = new_site()

        Plausible.Goals.create(site, %{"page_path" => "/home"})
        Plausible.Goals.create(site, %{"event_name" => "Signup"})

        Plausible.Goals.create(site, %{
          "page_path" => "/sites/new",
          "display_name" => "Create a site"
        })

        Plausible.Goals.create(site, %{"page_path" => "/site*"})

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
          build(:pageview,
            user_id: 123,
            pathname: "/sites/new",
            timestamp: DateTime.shift(now, minute: -260)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/sites",
            timestamp: DateTime.shift(now, minute: -250)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:event,
            user_id: 124,
            name: "Signup",
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -280)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/activate",
            timestamp: DateTime.shift(now, minute: -270)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/sites",
            timestamp: DateTime.shift(now, minute: -250)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:event,
            user_id: 125,
            name: "Signup",
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -280)
          ),
          build(:pageview,
            user_id: 126,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 126,
            pathname: "/register",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:pageview,
            user_id: 127,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok,
                [
                  next_step1,
                  next_step2,
                  next_step3,
                  next_step4,
                  next_step5,
                  next_step6,
                  next_step7
                ]} =
                 Exploration.next_steps(site, query, [])

        assert next_step1.step.label == "Visit /home"
        assert next_step1.step.name == "pageview"
        assert next_step1.step.pathname == "/home"
        assert next_step1.step.is_goal
        assert next_step1.visitors == 5

        assert next_step2.step.label == "/register"
        assert next_step2.step.name == "pageview"
        assert next_step2.step.pathname == "/register"
        refute next_step2.step.is_goal
        assert next_step2.visitors == 4

        assert next_step3.step.label == "Signup"
        assert next_step3.step.name == "Signup"
        assert next_step3.step.pathname == ""
        assert next_step3.step.is_goal
        assert next_step3.visitors == 3

        assert next_step4.step.label == "/activate"
        assert next_step4.step.name == "pageview"
        assert next_step4.step.pathname == "/activate"
        refute next_step4.step.is_goal
        assert next_step4.visitors == 2

        assert next_step5.step.label == "Visit /site*"
        assert next_step5.step.name == "pageview"
        assert next_step5.step.pathname == "/site*"
        assert next_step5.step.is_goal
        assert next_step5.visitors == 2

        assert next_step6.step.label == "/sites"
        assert next_step6.step.name == "pageview"
        assert next_step6.step.pathname == "/sites"
        refute next_step6.step.is_goal
        assert next_step6.visitors == 2

        assert next_step7.step.label == "Create a site"
        assert next_step7.step.name == "pageview"
        assert next_step7.step.pathname == "/sites/new"
        assert next_step7.step.is_goal
        assert next_step7.visitors == 1
      end

      test "allows searching for a pageview goal by its pathname" do
        now = DateTime.utc_now()
        site = new_site()

        Plausible.Goals.create(site, %{
          "page_path" => "/page-foo",
          "display_name" => "Foo"
        })

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/page-foo",
            timestamp: DateTime.shift(now, minute: -290)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"}
        ]

        assert {:ok, [next_step]} =
                 Exploration.next_steps(site, query, journey, search_term: "/page-foo")

        assert {:ok, [^next_step]} =
                 Exploration.next_steps(site, query, journey, search_term: "Foo")

        assert next_step.step.label == "Foo"
        assert next_step.step.pathname == "/page-foo"
        assert next_step.step.is_goal
        assert next_step.visitors == 1
      end

      test "won't find pageview event with verbatim `pageview` search" do
        now = DateTime.utc_now()
        site = new_site()

        Plausible.Goals.create(site, %{
          "page_path" => "/page-foo",
          "display_name" => "Foo"
        })

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/home",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/page-foo",
            timestamp: DateTime.shift(now, minute: -290)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "pageview", pathname: "/home"}
        ]

        assert {:ok, []} =
                 Exploration.next_steps(site, query, journey, search_term: "pageview")
      end

      test "allows searching for a literal event name" do
        now = DateTime.utc_now()
        site = new_site()

        Plausible.Goals.create(site, %{
          "event_name" => "actress",
          "display_name" => "Scarlett"
        })

        Plausible.Goals.create(site, %{
          "event_name" => "bishop",
          "display_name" => "Knight"
        })

        populate_stats(site, [
          build(:event,
            user_id: 123,
            name: "actress",
            pathname: "/lookup",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:event,
            user_id: 123,
            name: "bishop",
            pathname: "/lookup",
            timestamp: DateTime.shift(now, minute: -290)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{name: "actress", pathname: ""}
        ]

        assert {:ok, [next_step]} =
                 Exploration.next_steps(site, query, journey, search_term: "bishop")

        assert {:ok, [^next_step]} =
                 Exploration.next_steps(site, query, journey, search_term: "Knight")
      end

      test "suggestions matching implicit wildcard from previous step are excluded" do
        now = DateTime.utc_now()
        site = new_site()

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/a/b",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/a/b",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/a/b",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/a-blog",
            timestamp: DateTime.shift(now, minute: -290)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{
            name: "pageview",
            pathname: "/a",
            includes_subpaths: true,
            subpaths_count: 2
          }
        ]

        assert {:ok, [next_step1, next_step2]} = Exploration.next_steps(site, query, journey)

        assert next_step1.step.label == @journey_end_label
        assert next_step1.visitors == 2
        assert next_step2.step.label == "/a-blog"
        assert next_step2.visitors == 1
      end

      test "suggestions matching goal pattern from previous step are excluded" do
        now = DateTime.utc_now()
        site = new_site()

        Plausible.Goals.create(site, %{"page_path" => "/a*"})

        populate_stats(site, [
          build(:pageview,
            user_id: 123,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 123,
            pathname: "/a/b",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/a/b",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 124,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/a/b",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 125,
            pathname: "/a-blog",
            timestamp: DateTime.shift(now, minute: -290)
          ),
          build(:pageview,
            user_id: 126,
            pathname: "/a",
            timestamp: DateTime.shift(now, minute: -300)
          ),
          build(:pageview,
            user_id: 126,
            pathname: "/blog",
            timestamp: DateTime.shift(now, minute: -290)
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        journey = [
          %Exploration.Journey.Step{
            label: "Visit /a*",
            name: "pageview",
            pathname: "/a*",
            is_goal: true
          }
        ]

        assert {:ok, [next_step1, next_step2]} = Exploration.next_steps(site, query, journey)

        assert next_step1.step.label == @journey_end_label
        assert next_step1.visitors == 3
        assert next_step2.step.label == "/blog"
        assert next_step2.visitors == 1
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

        result = Exploration.next_steps(site, query, [])

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

        result = Exploration.next_steps(site, query, [], include_wildcard?: false)

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
