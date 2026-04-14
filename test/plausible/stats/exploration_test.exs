defmodule Plausible.Stats.ExplorationTest do
  use Plausible.DataCase

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
      assert step2.step.pathname == "/login"
      assert step2.visitors == 2
      assert step2.dropoff == 0
      assert step2.dropoff_percentage == "0"
      assert step3.step.pathname == "/logout"
      assert step3.visitors == 1
      assert step3.dropoff == 1
      assert step3.dropoff_percentage == "50"
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
      assert step2.step.pathname == "/login"
      assert step2.visitors == 1
      assert step2.dropoff == 0
      assert step2.dropoff_percentage == "0"
      assert step3.step.pathname == "/logout"
      assert step3.visitors == 0
      assert step3.dropoff == 1
      assert step3.dropoff_percentage == "100"
    end

    test "returns error on empty journey", %{site: site} do
      query = QueryBuilder.build!(site, input_date_range: :all)

      assert {:error, :empty_journey} = Exploration.journey_funnel(query, [])
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
      assert step1.visitors == 1
      assert step1.dropoff == 1
      assert step1.dropoff_percentage == "50"
      assert step2.step.pathname == "/login"
      assert step2.visitors == 2
      assert step2.dropoff == 0
      assert step2.dropoff_percentage == "0"
      assert step3.step.pathname == "/home"
      assert step3.visitors == 2
      assert step3.dropoff == 0
      assert step3.dropoff_percentage == "0"
    end
  end

  describe "next_steps" do
    test "suggests the next step for a 2-step journey", %{site: site} do
      query = QueryBuilder.build!(site, input_date_range: :all)

      journey = [
        %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
        %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
      ]

      assert {:ok, [next_step1, next_step2, next_step3]} = Exploration.next_steps(query, journey)

      assert next_step1.step.pathname == "/docs"
      assert next_step1.visitors == 1
      assert next_step2.step.pathname == "/home"
      assert next_step2.visitors == 1
      assert next_step3.step.pathname == "/logout"
      assert next_step3.visitors == 1
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

      assert {:ok, [next_step]} = Exploration.next_steps(query, journey, "doc")

      assert next_step.step.pathname == "/docs"
      assert next_step.visitors == 1
    end

    test "supports backward exploration", %{site: site} do
      query = QueryBuilder.build!(site, input_date_range: :all)

      journey = [
        %Exploration.Journey.Step{name: "pageview", pathname: "/logout"}
      ]

      assert {:ok, [next_step1, next_step2]} =
               Exploration.next_steps(query, journey, "", :backward)

      assert next_step1.step.pathname == "/docs"
      assert next_step1.visitors == 1
      assert next_step2.step.pathname == "/login"
      assert next_step2.visitors == 1
    end
  end
end
