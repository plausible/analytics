defmodule Plausible.FunnelsTest do
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
    {:ok, funnel} =
      Funnels.create(
        site,
        "From blog to signup and purchase",
        [g1, g2, g3],
        nil
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

  test "retrieve a funnel by id and site, get steps in order", %{site: site, goals: [g1, g2, g3]} do
    {:ok, funnel} =
      Funnels.create(
        site,
        "Lorem ipsum",
        [g3, g1, g2],
        nil
      )

    funnel = Funnels.get(site, funnel.id)
    assert funnel.name == "Lorem ipsum"
    assert [%{step_order: 1}, %{step_order: 2}, %{step_order: 3}] = funnel.steps
  end

  test "a funnel can be made of max n(TBD) goals" do
  end

  test "a funnel can be deleted" do
  end

  test "a goal can only appear once in a funnel", %{goals: [g1 | _], site: site} do
    {:error, changeset} =
      Funnels.create(
        site,
        "Lorem ipsum",
        [g1, g1],
        nil
      )
      |> IO.inspect(label: :err)
  end

  test "funnels can be listed per site", %{site: site, goals: [g1, g2, g3]} do
    Funnels.create(site, "Funnel 1", [g3, g1, g2], nil)
    Funnels.create(site, "Funnel 2", [g2, g1, g3], nil)

    funnels_list = Funnels.list(site)
    assert [%{name: "Funnel 1"}, %{name: "Funnel 2"}] = funnels_list
  end

  test "funnels can be evaluated per site within a time range", %{site: site, goals: goals} do
    {:ok, funnel} =
      Funnels.create(
        site,
        "From blog to signup and purchase",
        goals
      )

    populate_stats(site, [
      build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
      build(:event, name: "Signup", user_id: 123),
      build(:pageview, pathname: "/checkout", user_id: 123),
      build(:pageview, pathname: "/go/to/blog/bar", user_id: 666),
      build(:event, name: "Signup", user_id: 666)
    ])

    query = Plausible.Stats.Query.from(site, %{"period" => "all"})
    funnel_data = Funnels.evaluate(query, funnel.id, site.id)

    assert %{
             steps: [
               %{label: "Visit /go/to/blog/**", visitors: 2},
               %{label: "Signup", visitors: 2},
               %{label: "Visit /checkout", visitors: 1}
             ]
           } = funnel_data
  end
end
