defmodule Plausible.GoalsTest do
  use Plausible.DataCase

  alias Plausible.Goals
  alias Plausible.Funnels

  setup do
    site = insert(:site)

    {:ok, g1} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})
    {:ok, g2} = Goals.create(site, %{"event_name" => "Signup"})
    {:ok, g3} = Goals.create(site, %{"page_path" => "/checkout"})

    {:ok, %{site: site, goals: [g1, g2, g3]}}
  end

  test "create and store a funnel given a set of goals", %{site: site, goals: [g1, g2, g3]} do
    funnel =
      Funnels.create(
        site,
        "From blog to signup and purchase",
        [g1, g2, g3]
      )

    assert funnel.inserted_at
    assert funnel.name == "From blog to signup and purchase"
    assert [fg1, fg2, fg3] = funnel.steps

    assert fg1.goal_id == g1.id
    assert fg2.goal_id == g2.id
    assert fg3.goal_id == g3.id

    assert fg1.step_order == 1
    assert fg2.step_order == 2
    assert fg3.step_order == 3
  end

  test "retrieve a funnel by id and site", %{site: site, goals: goals} do
    funnel =
      Funnels.create(
        site,
        "Lorem ipsum",
        goals,
        nil
      )

    assert got =
             Funnels.get(site, funnel.id)
             |> IO.inspect(label: :got)
  end

  test "a funnel can be made of max n(TBD) goals" do
  end

  test "a funnel can be deleted" do
  end

  test "a goal can only appear once in a funnel" do
  end

  test "funnels can be listed per site" do
  end

  test "funnels can be evaluated per site within a time range", %{site: site, goals: goals} do
    funnel =
      Funnels.create(
        site,
        "From blog to signup and purchase",
        goals
      )

    populate_stats(site, [
      build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
      build(:event, name: "Signup", user_id: 123),
      build(:pageview, pathname: "/checkout", user_id: 123)
    ])

    query = Plausible.Stats.Query.from(site, %{"period" => "all"})
    funnel_data = Funnels.evaluate(query, funnel)

    assert %{
             steps: [%{step: 3, visitors: 1}]
           } = funnel_data
  end
end
