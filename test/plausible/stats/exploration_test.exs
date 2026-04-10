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
        pathname: "/logout",
        timestamp: DateTime.shift(now, minute: -15)
      )
    ])

    {:ok, site: site}
  end

  describe "journey_funnel" do
    test "it works", %{site: site} do
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
  end

  describe "next_steps" do
    test "it works", %{site: site} do
      query = QueryBuilder.build!(site, input_date_range: :all)

      journey = [
        %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
        %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
      ]

      assert {:ok, [next_step1, next_step2]} = Exploration.next_steps(query, journey)

      assert next_step1.step.pathname == "/docs"
      assert next_step1.visitors == 1
      assert next_step2.step.pathname == "/logout"
      assert next_step2.visitors == 1
    end

    test "it works for an empty journey", %{site: site} do
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

    test "it filters", %{site: site} do
      query = QueryBuilder.build!(site, input_date_range: :all)

      journey = [
        %Exploration.Journey.Step{name: "pageview", pathname: "/home"},
        %Exploration.Journey.Step{name: "pageview", pathname: "/login"}
      ]

      assert {:ok, [next_step]} = Exploration.next_steps(query, journey, "doc")

      assert next_step.step.pathname == "/docs"
      assert next_step.visitors == 1
    end
  end
end
