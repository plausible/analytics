defmodule Plausible.FunnelTest do
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    alias Plausible.Funnel
    alias Plausible.Funnels
    alias Plausible.Goal
    alias Plausible.Goals
    alias Plausible.Repo

    describe "changeset/2" do
      test "accepts and splits a set of static and dynamic steps" do
        site = new_site()

        {:ok, g1} =
          Goals.create(site, %{
            "page_path" => "/go/to/blog/**",
            "custom_props" => %{"lang" => "de"}
          })

        {:ok, g2} =
          Goals.create(site, %{
            "event_name" => "Purchase",
            "currency" => "USD"
          })

        params = %{
          name: "Example funnel",
          steps: [
            %{
              "goal_id" => g1.id,
              "goal" => %{
                "id" => g1.id,
                "event_name" => g1.event_name,
                "page_path" => g1.page_path,
                "custom_props" => %{"lang" => "de"}
              }
            },
            %{"event_name" => "Signup"},
            %{"page_path" => "/checkout", "scroll_threshold" => 90},
            %{
              "goal_id" => g2.id,
              "goal" => %{
                "id" => g2.id,
                "event_name" => g2.event_name,
                "page_path" => g2.page_path
              }
            }
          ]
        }

        changeset =
          Funnel.changeset(%Funnel{site_id: site.id}, params, allowed_goal_ids: [g1.id, g2.id])

        assert changeset.valid?

        funnel = apply_changes(changeset)

        assert_matches [
                         %Funnel.Step{
                           step_order: 1,
                           goal_id: ^g1.id,
                           goal: %{
                             event_name: ^g1.event_name,
                             page_path: ^g1.page_path,
                             custom_props: %{"lang" => "de"}
                           }
                         },
                         %Funnel.Step{
                           step_order: 4,
                           goal_id: ^g2.id,
                           goal: %{event_name: ^g2.event_name, page_path: ^g2.page_path}
                         }
                       ] = funnel.steps

        assert_matches [
                         %Funnel.DynamicStep{
                           step_order: 2,
                           event_name: "Signup",
                           page_path: nil
                         },
                         %Funnel.DynamicStep{
                           step_order: 3,
                           event_name: nil,
                           page_path: "/checkout",
                           scroll_threshold: 90
                         }
                       ] = funnel.dynamic_steps
      end

      test "handles empty steps list gracefully" do
        site = new_site()
        params = %{name: "Example funnel", steps: []}

        changeset = Funnel.changeset(%Funnel{site_id: site.id}, params)

        refute changeset.valid?
      end

      test "handles static steps only" do
        site = new_site()
        {:ok, g1} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})
        {:ok, g2} = Goals.create(site, %{"event_name" => "Signup"})
        {:ok, g3} = Goals.create(site, %{"page_path" => "/checkout"})

        params = %{
          name: "Example funnel",
          steps: [
            %{
              "goal_id" => g1.id,
              "goal" => %{
                "id" => g1.id,
                "event_name" => g1.event_name,
                "page_path" => g1.page_path
              }
            },
            %{
              "goal_id" => g2.id,
              "goal" => %{
                "id" => g2.id,
                "event_name" => g2.event_name,
                "page_path" => g2.page_path
              }
            },
            %{
              "goal_id" => g3.id,
              "goal" => %{
                "id" => g3.id,
                "event_name" => g3.event_name,
                "page_path" => g3.page_path
              }
            }
          ]
        }

        changeset =
          Funnel.changeset(%Funnel{site_id: site.id}, params,
            allowed_goal_ids: [g1.id, g2.id, g3.id]
          )

        assert changeset.valid?

        funnel = apply_changes(changeset)

        assert_matches [
                         %Funnel.Step{
                           step_order: 1,
                           goal_id: ^g1.id,
                           goal: %{event_name: ^g1.event_name, page_path: ^g1.page_path}
                         },
                         %Funnel.Step{
                           step_order: 2,
                           goal_id: ^g2.id,
                           goal: %{event_name: ^g2.event_name, page_path: ^g2.page_path}
                         },
                         %Funnel.Step{
                           step_order: 3,
                           goal_id: ^g3.id,
                           goal: %{event_name: ^g3.event_name, page_path: ^g3.page_path}
                         }
                       ] = funnel.steps

        assert_matches [] = funnel.dynamic_steps
      end

      test "handles dynamic steps only" do
        site = new_site()

        params = %{
          name: "Example funnel",
          steps: [
            %{"page_path" => "/go/to/blog/**"},
            %{"event_name" => "Signup"},
            %{"page_path" => "/checkout"}
          ]
        }

        changeset = Funnel.changeset(%Funnel{site_id: site.id}, params)

        assert changeset.valid?

        funnel = apply_changes(changeset)

        assert_matches [] = funnel.steps

        assert_matches [
                         %Funnel.DynamicStep{
                           step_order: 1,
                           event_name: nil,
                           page_path: "/go/to/blog/**"
                         },
                         %Funnel.DynamicStep{
                           step_order: 2,
                           event_name: "Signup",
                           page_path: nil
                         },
                         %Funnel.DynamicStep{
                           step_order: 3,
                           event_name: nil,
                           page_path: "/checkout"
                         }
                       ] = funnel.dynamic_steps
      end

      test "properly handles validation errors in steps" do
        site = new_site()

        params = %{
          name: "Example funnel",
          steps: [
            %{"page_path" => "/go/to/blog/**"},
            %{"event_name" => "Signup", "page_path" => "/should/be/empty"},
            %{"page_path" => "/checkout"}
          ]
        }

        changeset = Funnel.changeset(%Funnel{site_id: site.id}, params)

        refute changeset.valid?

        assert [_, %Ecto.Changeset{valid?: false}, _] = get_change(changeset, :dynamic_steps)
      end
    end

    describe "steps/1" do
      test "returns a continuous and ordered list of mixed dynamic and static steps" do
        site = new_site()
        {:ok, g} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})

        {:ok, funnel} =
          Funnels.create(site, "Example funnel", [
            %{"goal_id" => g.id},
            %{"event_name" => "Signup"},
            %{"page_path" => "/checkout"}
          ])

        assert [s1, s2, s3] = Funnel.steps(funnel)

        assert_matches %Funnel.Step{goal_id: ^g.id, step_order: 1} = s1
        assert %Funnel.DynamicStep{event_name: "Signup", step_order: 2} = s2
        assert %Funnel.DynamicStep{page_path: "/checkout", step_order: 3} = s3
      end
    end

    describe "goals/1" do
      test "returns a continuous and ordered list of goals extracted from mixed dynamic and static steps" do
        site = new_site()
        {:ok, g} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})

        {:ok, funnel} =
          Funnels.create(site, "Example funnel", [
            %{"goal_id" => g.id},
            %{"event_name" => "Signup"},
            %{"page_path" => "/checkout"}
          ])

        funnel = Repo.preload(funnel, steps: :goal)

        assert [g1, g2, g3] = Funnel.goals(funnel)

        assert_matches %Goal{id: ^g.id, event_name: ^g.event_name, page_path: ^g.page_path} = g1
        assert_matches %Goal{id: 0, event_name: "Signup", page_path: nil} = g2
        assert_matches %Goal{id: 0, event_name: nil, page_path: "/checkout"} = g3
      end

      test "crashes when static steps do not have goals preloaded" do
        site = new_site()
        {:ok, g} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})

        {:ok, funnel} =
          Funnels.create(site, "Example funnel", [
            %{"goal_id" => g.id},
            %{"event_name" => "Signup"}
          ])

        assert_raise RuntimeError, ~r/Expected goal, got:/, fn ->
          Funnel.goals(funnel)
        end
      end
    end

    describe "swap/2" do
      setup do
        site = new_site()
        {:ok, g1} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})
        {:ok, g2} = Goals.create(site, %{"event_name" => "Purchase"})

        {:ok, funnel} =
          Funnels.create(site, "Example funnel", [
            %{"goal_id" => g1.id},
            %{"event_name" => "Signup"},
            %{"page_path" => "/checkout"},
            %{"goal_id" => g2.id}
          ])

        {:ok, funnel: funnel}
      end

      test "swaps a mix of static and dynamic steps in the funnel", %{funnel: funnel} do
        [s1, _s2, s3, _s4] = Funnel.steps(funnel)

        swapped = Funnel.swap(funnel, steps: [s1, s3])

        assert [sw1] = swapped.steps
        assert [sw2] = swapped.dynamic_steps

        assert sw1.goal_id == s1.goal_id
        assert sw1.step_order == 1
        assert sw2.page_path == "/checkout"
        assert sw2.step_order == 2
      end

      test "handles no steps to swap gracefully", %{funnel: funnel} do
        swapped = Funnel.swap(funnel, [])

        assert funnel == swapped
      end

      test "crashes on too few steps passed for swapping", %{funnel: funnel} do
        [s1, _s2, _s3, _s4] = Funnel.steps(funnel)

        assert_raise FunctionClauseError, fn ->
          Funnel.swap(funnel, steps: [s1])
        end

        assert_raise FunctionClauseError, fn ->
          Funnel.swap(funnel, steps: [])
        end
      end

      test "handles static steps only", %{funnel: funnel} do
        [s1, _s2, _s3, s4] = Funnel.steps(funnel)

        swapped = Funnel.swap(funnel, steps: [s1, s4])

        assert [sw1, sw2] = swapped.steps
        assert [] = swapped.dynamic_steps

        assert sw1.goal_id == s1.goal_id
        assert sw1.step_order == 1
        assert sw2.goal_id == s4.goal_id
        assert sw2.step_order == 2
      end

      test "handles dynamic steps only", %{funnel: funnel} do
        [_s1, s2, s3, _s4] = Funnel.steps(funnel)

        swapped = Funnel.swap(funnel, steps: [s2, s3])

        assert [] = swapped.steps
        assert [sw1, sw2] = swapped.dynamic_steps

        assert sw1.event_name == "Signup"
        assert sw1.step_order == 1
        assert sw2.page_path == "/checkout"
        assert sw2.step_order == 2
      end
    end
  end
end
