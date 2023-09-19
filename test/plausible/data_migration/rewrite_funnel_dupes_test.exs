defmodule Plausible.DataMigration.RewriteFunnelDupesTest do
  use Plausible.DataCase, async: true

  alias Plausible.DataMigration.RewriteFunnelDupes

  import ExUnit.CaptureIO

  for goal_type <- ["event_name", "page_path"] do
    test "deletes a funnel that cannot be cleaned up from dupe goals (#{goal_type})" do
      site = insert(:site)

      goals =
        setup_goals!(site, [
          %{unquote(goal_type) => "/AAA"},
          %{unquote(goal_type) => "/AAA"},
          %{unquote(goal_type) => "/AAA"}
        ])

      funnel = setup_funnel!(site, "test", goals)

      io = assert capture_io(fn -> RewriteFunnelDupes.run() end)
      assert io =~ "Processing site ID: #{site.id}"
      assert io =~ "Deleting whole funnel"

      refute Repo.reload(funnel)
    end

    test "reduces a funnel if possible (#{goal_type})" do
      site = insert(:site)

      goals =
        setup_goals!(site, [
          %{unquote(goal_type) => "/AAA"},
          %{unquote(goal_type) => "/BBB"},
          %{unquote(goal_type) => "/AAA"},
          %{unquote(goal_type) => "/CCC"}
        ])

      funnel = setup_funnel!(site, "test", goals)

      io = assert capture_io(fn -> RewriteFunnelDupes.run() end)
      assert io =~ "Processing site ID: #{site.id}"
      assert io =~ "Deleting step"

      assert_funnel(site.id, funnel.id, [
        %{unquote(goal_type) => "/AAA"},
        %{unquote(goal_type) => "/BBB"},
        %{unquote(goal_type) => "/CCC"}
      ])
    end
  end

  test "dupe names in mixed goal types don't matter" do
    site = insert(:site)

    gs = [
      %{"event_name" => "/AAA"},
      %{"page_path" => "/AAA"},
      %{"event_name" => "/foo"},
      %{"page_path" => "/foo"}
    ]

    goals = setup_goals!(site, gs)

    funnel = setup_funnel!(site, "test", goals)

    capture_io(fn -> RewriteFunnelDupes.run() end)

    assert_funnel(site.id, funnel.id, gs)
  end

  test "goals across multiple funnels" do
    site = insert(:site)

    goals = [
      %{"event_name" => "/AAA"},
      %{"event_name" => "/AAA"},
      %{"page_path" => "/foo"},
      %{"event_name" => "/AAA"}
    ]

    [g1, g2, g3, g4] = setup_goals!(site, goals)

    funnel1 = setup_funnel!(site, "test1", [g1, g2, g3, g4])
    funnel2 = setup_funnel!(site, "test2", [g2, g1, g3, g4])
    funnel3 = setup_funnel!(site, "test3", [g2, g3])
    funnel4 = setup_funnel!(site, "test4", [g2, g1])

    capture_io(fn -> RewriteFunnelDupes.run() end)

    assert_funnel(site.id, funnel1.id, [%{"event_name" => "/AAA"}, %{"page_path" => "/foo"}])
    assert_funnel(site.id, funnel2.id, [%{"event_name" => "/AAA"}, %{"page_path" => "/foo"}])
    assert_funnel(site.id, funnel3.id, [%{"event_name" => "/AAA"}, %{"page_path" => "/foo"}])

    refute Plausible.Funnels.get(site.id, funnel4.id)
  end

  defp setup_goals!(site, goals) do
    for goal <- goals do
      {:ok, g} = Plausible.Goals.create(site, goal)
      g
    end
  end

  def setup_funnel!(site, name, goals) do
    {:ok, funnel} = Plausible.Funnels.create(site, name, Enum.map(goals, &%{"goal_id" => &1.id}))
    funnel
  end

  def assert_funnel(site_id, funnel_id, goals) do
    funnel_goals =
      Plausible.Funnels.get(site_id, funnel_id)
      |> Map.fetch!(:steps)
      |> Enum.map(& &1.goal)

    assert Enum.count(funnel_goals) == Enum.count(goals)

    Enum.zip(funnel_goals, goals)
    |> Enum.each(fn {funnel_goal, expect} ->
      key = Map.keys(expect) |> List.first() |> String.to_existing_atom()
      assert Map.fetch!(funnel_goal, key) == Map.values(expect) |> List.first()
    end)
  end
end
