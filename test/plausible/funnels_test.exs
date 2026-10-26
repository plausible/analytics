defmodule Plausible.FunnelsTest do
  use Plausible.DataCase
  @moduletag :ee_only

  on_ee do
    alias Plausible.Funnel
    alias Plausible.Funnels
    alias Plausible.Goals

    setup do
      site = new_site()

      {:ok, g1} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})
      {:ok, g2} = Goals.create(site, %{"event_name" => "Signup"})
      {:ok, g3} = Goals.create(site, %{"page_path" => "/checkout"})
      {:ok, g4} = Goals.create(site, %{"event_name" => "Leave feedback"})
      {:ok, g5} = Goals.create(site, %{"page_path" => "/recommend"})
      {:ok, g6} = Goals.create(site, %{"event_name" => "Extra event"})
      {:ok, g7} = Goals.create(site, %{"event_name" => "Extra event 2"})
      {:ok, g8} = Goals.create(site, %{"event_name" => "Extra event 3"})
      {:ok, g9} = Goals.create(site, %{"event_name" => "Extra event 4"})

      {:ok,
       %{
         site: site,
         goals: [g1, g2, g3],
         steps: [g1, g2, g3, g4, g5, g6, g7, g8, g9] |> Enum.map(&%{"goal_id" => &1.id})
       }}
    end

    describe "Common context" do
      test "create and store a funnel given a set of goals", %{
        site: site,
        steps: [g1, g2, g3 | _]
      } do
        {:ok, funnel} =
          Funnels.create(
            site,
            "From blog to signup and purchase",
            [g1, g2, g3]
          )

        assert funnel.inserted_at
        assert funnel.name == "From blog to signup and purchase"
        assert funnel.funnel_type == :sequential
        assert funnel.strict_order == false
        assert funnel.first_and_last == false
        assert [fg1, fg2, fg3] = Funnel.steps(funnel)

        assert fg1.goal_id == g1["goal_id"]
        assert fg2.goal_id == g2["goal_id"]
        assert fg3.goal_id == g3["goal_id"]

        assert fg1.step_order == 1
        assert fg2.step_order == 2
        assert fg3.step_order == 3
      end

      test "create a mixed static/dynamic funnel", %{site: site, steps: [g1 | _]} do
        s2 = %{"event_name" => "Signup"}
        s3 = %{"page_path" => "/checkout"}

        {:ok, funnel} =
          Funnels.create(
            site,
            "From blog to signup and purchase",
            [g1, s2, s3]
          )

        assert funnel.inserted_at
        assert funnel.name == "From blog to signup and purchase"
        assert funnel.strict_order == false

        assert [%Funnel.Step{} = fg1, %Funnel.DynamicStep{} = fg2, %Funnel.DynamicStep{} = fg3] =
                 Funnel.steps(funnel)

        assert fg1.goal_id == g1["goal_id"]
        assert fg2.event_name == s2["event_name"]
        assert fg3.page_path == s3["page_path"]

        assert fg1.step_order == 1
        assert fg2.step_order == 2
        assert fg3.step_order == 3
      end

      test "update funnel", %{site: site, steps: [g1, g2, g3, g4, g5 | _]} do
        {:ok, funnel1} =
          Funnels.create(
            site,
            "Sample funnel",
            [g1, g2, g3]
          )

        {:ok, funnel2} = Funnels.update(funnel1, "Updated funnel", [g4, g5])

        assert funnel2.name == "Updated funnel"
        assert [fg1, fg2] = Funnel.steps(funnel2)

        assert fg1.goal_id == g4["goal_id"]
        assert fg2.goal_id == g5["goal_id"]

        assert fg1.step_order == 1
        assert fg2.step_order == 2

        assert funnel1.id == funnel2.id
      end

      test "update funnel name and type only, keeping steps", %{
        site: site,
        steps: [g1, g2 | _]
      } do
        {:ok, funnel} = Funnels.create(site, "Sample funnel", [g1, %{"page_path" => "/x"}, g2])
        funnel = Funnels.get(site, funnel.id)

        {:ok, _} = Funnels.update(funnel, "Renamed funnel", nil, funnel_type: :strict)

        funnel = Funnels.get(site, funnel.id)
        assert funnel.name == "Renamed funnel"
        assert funnel.funnel_type == :strict
        assert [%{goal_id: g1_id}, %{page_path: "/x"}, %{goal_id: g2_id}] = Funnel.steps(funnel)
        assert g1_id == g1["goal_id"]
        assert g2_id == g2["goal_id"]
      end

      test "update funnel reordering the same static steps", %{
        site: site,
        steps: [g1, g2, g3 | _]
      } do
        {:ok, funnel} = Funnels.create(site, "Sample funnel", [g1, g2, g3])
        funnel = Funnels.get(site, funnel.id)

        {:ok, _} = Funnels.update(funnel, funnel.name, [g3, g1, g2])

        funnel = Funnels.get(site, funnel.id)

        assert Enum.map(Funnel.steps(funnel), & &1.goal_id) ==
                 Enum.map([g3, g1, g2], & &1["goal_id"])
      end

      test "steps referencing goals of other sites are rejected", %{site: site, steps: [g1 | _]} do
        other_site = new_site()
        {:ok, other_goal} = Goals.create(other_site, %{"event_name" => "Signup"})

        assert {:error, :invalid_goal} =
                 Funnels.create(site, "Foreign", [g1, %{"goal_id" => other_goal.id}])

        assert {:error, :invalid_goal} =
                 Funnels.create(site, "Garbage", [g1, %{"goal_id" => "abc"}])
      end

      test "journey end cannot be a funnel step", %{site: site, steps: [g1 | _]} do
        assert {:error, :invalid_step} =
                 Funnels.create(site, "Journey end", [g1, %{"event_name" => "__journey_end__"}])
      end

      test "unsupported dynamic step fields are dropped", %{site: site, steps: [g1 | _]} do
        {:ok, funnel} =
          Funnels.create(site, "Extra fields", [
            g1,
            %{"page_path" => "/x", "label" => "Visit /x", "step_order" => 99}
          ])

        assert [_, %Funnel.DynamicStep{page_path: "/x", step_order: 2}] = Funnel.steps(funnel)
      end

      test "dynamic steps can only appear once in a funnel", %{site: site, steps: [g1 | _]} do
        assert {:error, changeset} =
                 Funnels.create(site, "Repeating", [
                   %{"page_path" => "/x"},
                   g1,
                   %{"page_path" => "/x"}
                 ])

        assert {"must be unique", _} = changeset.errors[:steps]

        assert {:ok, _} =
                 Funnels.create(site, "Different props", [
                   %{"event_name" => "Purchase"},
                   %{"event_name" => "Purchase", "custom_props" => %{"plan" => "pro"}}
                 ])
      end

      test "updating strict funnel with out of sync funnel type does not alter the type", %{
        site: site,
        steps: [g1, g2, g3, g4, g5 | _]
      } do
        {:ok, funnel1} =
          Funnels.create(
            site,
            "Sample funnel",
            [g1, g2, g3],
            funnel_type: :strict
          )

        funnel1 = funnel1 |> Ecto.Changeset.change(funnel_type: :sequential) |> Repo.update!()

        {:ok, funnel2} = Funnels.update(funnel1, "Updated funnel", [g4, g5])

        assert funnel2.name == "Updated funnel"
        assert funnel1.id == funnel2.id

        assert funnel2.strict_order == true
        assert funnel2.first_and_last == false
        assert funnel2.funnel_type == :sequential
      end

      test "update funnel to strict", %{site: site, steps: [g1, g2, g3 | _]} do
        {:ok, funnel} =
          Funnels.create(
            site,
            "Sample funnel",
            [g1, g2]
          )

        assert funnel.funnel_type == :sequential
        assert funnel.strict_order == false
        assert funnel.first_and_last == false

        {:ok, strict_funnel} =
          Funnels.update(
            funnel,
            "Sample funnel",
            [g1, g2, g3],
            funnel_type: :strict
          )

        assert strict_funnel.funnel_type == :strict
        assert strict_funnel.strict_order == true
        assert strict_funnel.first_and_last == false

        {:ok, preserved_funnel} =
          Funnels.update(
            strict_funnel,
            "Sample funnel",
            [g1, g2]
          )

        assert preserved_funnel.funnel_type == :strict
        assert preserved_funnel.strict_order == true
        assert preserved_funnel.first_and_last == false
      end

      test "update funnel to flexible", %{site: site, steps: [g1, g2, g3 | _]} do
        {:ok, funnel} =
          Funnels.create(
            site,
            "Sample funnel",
            [g1, g2]
          )

        assert funnel.funnel_type == :sequential
        assert funnel.strict_order == false
        assert funnel.first_and_last == false

        {:ok, flexible_funnel} =
          Funnels.update(
            funnel,
            "Sample funnel",
            [g1, g2, g3],
            funnel_type: :flexible
          )

        assert flexible_funnel.funnel_type == :flexible
        assert flexible_funnel.strict_order == false
        assert flexible_funnel.first_and_last == true

        {:ok, preserved_funnel} =
          Funnels.update(
            flexible_funnel,
            "Sample funnel",
            [g1, g2]
          )

        assert preserved_funnel.funnel_type == :flexible
        assert preserved_funnel.strict_order == false
        assert preserved_funnel.first_and_last == true
      end

      test "update funnel to sequential", %{site: site, steps: [g1, g2, g3 | _]} do
        {:ok, funnel} =
          Funnels.create(
            site,
            "Sample funnel",
            [g1, g2],
            funnel_type: :strict
          )

        assert funnel.funnel_type == :strict
        assert funnel.strict_order == true
        assert funnel.first_and_last == false

        {:ok, sequential_funnel} =
          Funnels.update(
            funnel,
            "Sample funnel",
            [g1, g2, g3],
            funnel_type: :sequential
          )

        assert sequential_funnel.funnel_type == :sequential
        assert sequential_funnel.strict_order == false
        assert sequential_funnel.first_and_last == false

        {:ok, preserved_funnel} =
          Funnels.update(
            sequential_funnel,
            "Sample funnel",
            [g1, g2]
          )

        assert preserved_funnel.funnel_type == :sequential
        assert preserved_funnel.strict_order == false
        assert preserved_funnel.first_and_last == false
      end

      test "retrieve a funnel by id and site, get steps in order", %{
        site: site,
        steps: [g1, g2, g3 | _]
      } do
        {:ok, funnel} =
          Funnels.create(
            site,
            "Lorem ipsum",
            [g3, g1, g2]
          )

        assert funnel = Funnels.get(site, funnel.id)
        assert funnel.name == "Lorem ipsum"
        assert [%{step_order: 1}, %{step_order: 2}, %{step_order: 3}] = Funnel.steps(funnel)
      end

      test "funnels can be deleted by id and a site", %{site: site, steps: [g1, g2 | _]} do
        {:ok, funnel} =
          Funnels.create(
            site,
            "Sample funnel",
            [g1, g2]
          )

        assert :ok = Funnels.delete(site, funnel.id)
        # deletion is idempotent
        assert :ok = Funnels.delete(site, funnel.id)
        refute Funnels.get(site, funnel.id)
      end

      test "a funnel cannot be made of < 2 steps", %{site: site, steps: [g1 | _]} do
        assert {:error, :invalid_funnel_size} =
                 Funnels.create(
                   site,
                   "Lorem ipsum",
                   [g1]
                 )
      end

      test "a funnel can be made of 8 steps maximum", %{site: site, steps: too_many_steps} do
        assert {:ok, _} =
                 Funnels.create(
                   site,
                   "Lorem ipsum",
                   Enum.take(too_many_steps, 8)
                 )

        assert {:error, :invalid_funnel_size} =
                 Funnels.create(
                   site,
                   "Lorem ipsum",
                   too_many_steps
                 )
      end

      test "a goal can only appear once in a funnel", %{steps: [g1 | _], site: site} do
        {:error, changeset} =
          Funnels.create(
            site,
            "Lorem ipsum",
            [g1, g1]
          )

        assert {"must be unique", _} = changeset.errors[:steps]
      end

      test "funnels can be listed per site, starting from most recently added", %{
        site: site,
        steps: [g1, g2, g3 | _]
      } do
        Funnels.create(site, "Funnel 1", [g3, g1])
        Funnels.create(site, "Funnel 2", [g2, g1, g3])

        funnels_list = Funnels.list(site)

        assert [%{name: "Funnel 2", steps_count: 3}, %{name: "Funnel 1", steps_count: 2}] =
                 funnels_list
      end

      test "funnels with dynamic steps are listed correctly", %{
        site: site,
        steps: [g1, _g2, g3 | _]
      } do
        Funnels.create(site, "Funnel 1", [g3, %{"page_path" => "/go/to/blog/**"}])
        Funnels.create(site, "Funnel 2", [%{"event_name" => "Signup"}, g1, g3])

        funnels_list = Funnels.list(site)

        assert [%{name: "Funnel 2", steps_count: 3}, %{name: "Funnel 1", steps_count: 2}] =
                 funnels_list
      end
    end
  end
end
