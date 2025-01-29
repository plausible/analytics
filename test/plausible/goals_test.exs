defmodule Plausible.GoalsTest do
  use Plausible.DataCase
  use Plausible
  use Plausible.Teams.Test
  alias Plausible.Goals

  test "create/2 creates goals and trims input" do
    site = new_site()
    {:ok, goal} = Goals.create(site, %{"page_path" => "/foo bar "})
    assert goal.page_path == "/foo bar"
    assert goal.display_name == "Visit /foo bar"

    {:ok, goal} =
      Goals.create(site, %{
        "event_name" => "  some event name   ",
        "display_name" => " DisplayName   "
      })

    assert goal.event_name == "some event name"
    assert goal.display_name == "DisplayName"
  end

  test "create/2 creates pageview goal and adds a leading slash if missing" do
    site = new_site()
    {:ok, goal} = Goals.create(site, %{"page_path" => "foo bar"})
    assert goal.page_path == "/foo bar"
  end

  test "create/2 validates goal name is at most 120 chars" do
    site = new_site()
    assert {:error, changeset} = Goals.create(site, %{"event_name" => String.duplicate("a", 130)})
    assert {"should be at most %{count} character(s)", _} = changeset.errors[:event_name]
  end

  test "create/2 validates scroll_threshold in range [-1, 100]" do
    site = new_site()

    {:error, changeset} =
      Goals.create(site, %{"page_path" => "/blog/post-1", "scroll_threshold" => -2})

    assert {"Should be -1 (missing) or in range [0, 100]", _} =
             changeset.errors[:scroll_threshold]

    {:error, changeset} =
      Goals.create(site, %{"page_path" => "/blog/post-1", "scroll_threshold" => 101})

    assert {"Should be -1 (missing) or in range [0, 100]", _} =
             changeset.errors[:scroll_threshold]

    assert {:ok, _} =
             Goals.create(site, %{"page_path" => "/blog/post-1", "scroll_threshold" => -1})

    assert {:ok, _} =
             Goals.create(site, %{"page_path" => "/blog/post-2", "scroll_threshold" => 50})
  end

  test "create/2 validates page path exists for scroll goals" do
    site = new_site()

    {:error, changeset} =
      Goals.create(site, %{"event_name" => "Signup", "scroll_threshold" => 50})

    assert {"page_path field missing for page scroll goal", _} =
             changeset.errors[:scroll_threshold]
  end

  test "create/2 validates uniqueness across page_path and scroll_threshold" do
    site = new_site()

    {:ok, _} =
      Goals.create(site, %{
        "page_path" => "/blog/post-1",
        "scroll_threshold" => 50,
        "display_name" => "Scroll 50"
      })

    {:ok, _} =
      Goals.create(site, %{
        "page_path" => "/blog/post-1",
        "scroll_threshold" => 75,
        "display_name" => "Scroll 75"
      })

    {:error, changeset} =
      Goals.create(site, %{
        "page_path" => "/blog/post-1",
        "scroll_threshold" => 50,
        "display_name" => "Scroll 50 another"
      })

    assert {"has already been taken", _} =
             changeset.errors[:page_path]
  end

  test "create/2 fails to create the same pageview goal twice" do
    site = new_site()
    {:ok, _} = Goals.create(site, %{"page_path" => "foo bar", "display_name" => "one"})

    assert {:error, changeset} =
             Goals.create(site, %{"page_path" => "foo bar", "display_name" => "two"})

    assert {"has already been taken", _} =
             changeset.errors[:page_path]
  end

  test "create/2 fails to create the same custom event goal twice" do
    site = new_site()
    {:ok, _} = Goals.create(site, %{"event_name" => "foo bar"})
    assert {:error, changeset} = Goals.create(site, %{"event_name" => "foo bar"})
    assert {"has already been taken", _} = changeset.errors[:event_name]
  end

  test "create/2 fails to create the same currency goal twice" do
    site = new_site()
    {:ok, _} = Goals.create(site, %{"event_name" => "foo bar", "currency" => "EUR"})

    assert {:error, changeset} =
             Goals.create(site, %{"event_name" => "foo bar", "currency" => "EUR"})

    assert {"has already been taken", _} = changeset.errors[:event_name]
  end

  test "create/2 fails to create a goal with 'pageleave' as event_name (reserved)" do
    site = new_site()
    assert {:error, changeset} = Goals.create(site, %{"event_name" => "pageleave"})

    assert {"The event name 'pageleave' is reserved and cannot be used as a goal", _} =
             changeset.errors[:event_name]
  end

  @tag :ee_only
  test "create/2 sets site.updated_at for revenue goal" do
    site_1 = new_site(updated_at: DateTime.add(DateTime.utc_now(), -3600))

    {:ok, _goal_1} = Goals.create(site_1, %{"event_name" => "Checkout", "currency" => "BRL"})

    assert NaiveDateTime.compare(site_1.updated_at, Plausible.Repo.reload!(site_1).updated_at) ==
             :lt

    site_2 = new_site(updated_at: DateTime.add(DateTime.utc_now(), -3600))
    {:ok, _goal_2} = Goals.create(site_2, %{"event_name" => "Read Article", "currency" => nil})

    assert NaiveDateTime.compare(site_2.updated_at, Plausible.Repo.reload!(site_2).updated_at) ==
             :eq
  end

  @tag :ee_only
  test "create/2 creates revenue goal" do
    site = new_site()
    {:ok, goal} = Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})
    assert goal.event_name == "Purchase"
    assert goal.page_path == nil
    assert goal.currency == :EUR
  end

  @tag :ee_only
  test "create/2 returns error when site does not have access to revenue goals" do
    user = new_user() |> subscribe_to_growth_plan()
    site = new_site(owner: user)

    {:error, :upgrade_required} =
      Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})
  end

  @tag :ee_only
  test "create/2 fails for unknown currency code" do
    site = new_site()

    assert {:error, changeset} =
             Goals.create(site, %{"event_name" => "Purchase", "currency" => "Euro"})

    assert [currency: {"is invalid", _}] = changeset.errors
  end

  test "update/2 updates a goal" do
    site = new_site()
    {:ok, goal1} = Goals.create(site, %{"page_path" => "/foo bar "})
    {:ok, goal2} = Goals.update(goal1, %{"page_path" => "/", "display_name" => "Homepage"})
    assert goal1.id == goal2.id
    assert goal2.page_path == "/"
    assert goal2.display_name == "Homepage"
  end

  @tag :ee_only
  test "list_revenue_goals/1 lists event_names and currencies for each revenue goal" do
    site = new_site()

    Goals.create(site, %{"event_name" => "One", "currency" => "EUR"})
    Goals.create(site, %{"event_name" => "Two", "currency" => "EUR"})
    Goals.create(site, %{"event_name" => "Three", "currency" => "USD"})
    Goals.create(site, %{"event_name" => "Four"})
    Goals.create(site, %{"page_path" => "/some-page"})

    revenue_goals = Goals.list_revenue_goals(site)

    assert length(revenue_goals) == 3
    assert %{display_name: "One", currency: :EUR} in revenue_goals
    assert %{display_name: "Two", currency: :EUR} in revenue_goals
    assert %{display_name: "Three", currency: :USD} in revenue_goals
  end

  test "create/2 clears currency for pageview goals" do
    site = new_site()
    {:ok, goal} = Goals.create(site, %{"page_path" => "/purchase", "currency" => "EUR"})
    assert goal.event_name == nil
    assert goal.page_path == "/purchase"
    assert goal.currency == nil
  end

  test "for_site/1 returns trimmed input even if it was saved with trailing whitespace" do
    site = new_site()
    insert(:goal, %{site: site, event_name: " Signup "})
    insert(:goal, %{site: site, page_path: " /Signup "})

    goals = Goals.for_site(site)

    assert [%{page_path: "/Signup"}, %{event_name: "Signup"}] = goals
  end

  test "goals are present after domain change" do
    site = new_site()
    insert(:goal, %{site: site, event_name: " Signup "})
    insert(:goal, %{site: site, page_path: " /Signup "})

    {:ok, site} = Plausible.Site.Domain.change(site, "goals.example.com")

    assert [_, _] = Goals.for_site(site)
  end

  test "goals are removed when site is deleted" do
    site = new_site()
    insert(:goal, %{site: site, event_name: " Signup "})
    insert(:goal, %{site: site, page_path: " /Signup "})

    Plausible.Site.Removal.run(site)

    assert [] = Goals.for_site(site)
  end

  test "goals can be deleted" do
    site = new_site()
    goal = insert(:goal, %{site: site, event_name: " Signup "})
    :ok = Goals.delete(goal.id, site)
    assert [] = Goals.for_site(site)
  end

  on_ee do
    test "goals can be fetched with funnel count preloaded" do
      site = new_site()

      goals =
        Enum.map(1..4, fn i ->
          {:ok, g} = Goals.create(site, %{"page_path" => "/#{i}"})
          g
        end)

      {:ok, %{id: funnel_id1}} =
        Plausible.Funnels.create(
          site,
          "Funnel1",
          [
            %{"goal_id" => Enum.at(goals, 1).id},
            %{"goal_id" => Enum.at(goals, 2).id},
            %{"goal_id" => Enum.at(goals, 3).id}
          ]
        )

      {:ok, %{id: funnel_id2}} =
        Plausible.Funnels.create(
          site,
          "Funnel2",
          [
            %{"goal_id" => Enum.at(goals, 1).id},
            %{"goal_id" => Enum.at(goals, 3).id}
          ]
        )

      assert [goal, _, _, _] = Goals.for_site(site, preload_funnels?: false)
      assert %Ecto.Association.NotLoaded{} = goal.funnels

      assert [goal, _, _, _] = Goals.for_site(site, preload_funnels?: true)
      assert [%{id: ^funnel_id1}, %{id: ^funnel_id2}] = goal.funnels
    end

    test "deleting goals with funnels triggers funnel reduction" do
      site = new_site()
      {:ok, g1} = Goals.create(site, %{"page_path" => "/1"})
      {:ok, g2} = Goals.create(site, %{"page_path" => "/2"})
      {:ok, g3} = Goals.create(site, %{"page_path" => "/3"})

      {:ok, f1} =
        Plausible.Funnels.create(
          site,
          "Funnel 3 steps",
          [
            %{"goal_id" => g1.id},
            %{"goal_id" => g2.id},
            %{"goal_id" => g3.id}
          ]
        )

      {:ok, f2} =
        Plausible.Funnels.create(
          site,
          "Funnel 2 steps",
          [
            %{"goal_id" => g1.id},
            %{"goal_id" => g2.id}
          ]
        )

      :ok = Goals.delete(g1.id, site)

      assert f1 = Plausible.Funnels.get(site.id, f1.id)
      assert Enum.count(f1.steps) == 2

      refute Plausible.Funnels.get(site.id, f2.id)
      assert Repo.all(from(fs in Plausible.Funnel.Step, where: fs.funnel_id == ^f2.id)) == []

      assert [^g3, ^g2] = Goals.for_site(site)
    end
  end

  test "must be either page_path or event_name" do
    site = new_site()

    assert {:error, changeset} =
             Goals.create(site, %{"page_path" => "/foo", "event_name" => "/foo"})

    assert {"cannot co-exist with page_path", _} = changeset.errors[:event_name]
  end
end
