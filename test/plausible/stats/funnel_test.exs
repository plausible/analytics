defmodule Plausible.Stats.FunnelTest do
  use Plausible.DataCase

  @moduletag :ee_only

  on_ee do
    alias Plausible.Funnels
    alias Plausible.Goals
    alias Plausible.Stats
    alias Plausible.Stats.QueryBuilder

    setup do
      site = new_site()

      {:ok, g1} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})
      {:ok, g2} = Goals.create(site, %{"event_name" => "Signup"})
      {:ok, g3} = Goals.create(site, %{"page_path" => "/checkout"})

      {:ok,
       %{
         site: site,
         goals: [g1, g2, g3],
         steps: [g1, g2, g3] |> Enum.map(&%{"goal_id" => &1.id})
       }}
    end

    describe "candidates/3" do
      test "returns all goals with zero visitors when there are no stats", %{
        site: site,
        goals: [g1, g2, g3]
      } do
        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, candidates} = Stats.Funnel.candidates(site, query)

        assert candidates |> Enum.map(& &1.step.goal_id) |> Enum.sort() ==
                 Enum.sort([g1.id, g2.id, g3.id])

        assert Enum.all?(candidates, &(&1.visitors == 0 and &1.step.is_goal))
      end

      test "lists goals of all kinds with visitor counts, along with pages and events not covered by goals",
           %{site: site, goals: [g1, g2, g3]} do
        {:ok, scroll} =
          Goals.create(site, %{
            "page_path" => "/checkout",
            "scroll_threshold" => 50,
            "display_name" => "Scroll checkout"
          })

        {:ok, props} =
          Goals.create(site, %{
            "event_name" => "Signup",
            "custom_props" => %{"plan" => "pro"},
            "display_name" => "Pro signup"
          })

        {:ok, revenue} = Goals.create(site, %{"event_name" => "Purchase", "currency" => "USD"})

        populate_stats(site, [
          build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
          build(:event,
            name: "Signup",
            user_id: 123,
            "meta.key": ["plan"],
            "meta.value": ["pro"]
          ),
          build(:pageview, pathname: "/checkout", user_id: 123),
          build(:engagement, pathname: "/checkout", user_id: 123, scroll_depth: 60),
          build(:event,
            name: "Purchase",
            user_id: 123,
            revenue_reporting_amount: Decimal.new("10"),
            revenue_reporting_currency: "USD"
          ),
          build(:pageview, pathname: "/go/to/blog/bar", user_id: 666),
          build(:event, name: "Signup", user_id: 666),
          build(:pageview, pathname: "/about", user_id: 666)
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, candidates} = Stats.Funnel.candidates(site, query)

        by_goal =
          candidates
          |> Enum.filter(& &1.step.goal_id)
          |> Map.new(&{&1.step.goal_id, &1})

        assert %{visitors: 2, step: %{label: "Visit /go/to/blog/**", goal_kind: nil}} =
                 by_goal[g1.id]

        assert %{visitors: 2, step: %{label: "Signup", name: "Signup"}} = by_goal[g2.id]
        assert %{visitors: 1, step: %{label: "Visit /checkout"}} = by_goal[g3.id]
        assert %{visitors: 1, step: %{goal_kind: :scroll}} = by_goal[scroll.id]
        assert %{visitors: 1, step: %{label: "Pro signup", goal_kind: :props}} = by_goal[props.id]
        assert %{visitors: 1, step: %{goal_kind: :revenue}} = by_goal[revenue.id]

        pages =
          candidates
          |> Enum.reject(& &1.step.is_goal)
          |> Enum.map(&{&1.step.name, &1.step.pathname, &1.step.includes_subpaths})

        assert {"pageview", "/about", false} in pages
        assert {"pageview", "/go/to/blog/foo", false} in pages
        # covered by the plain goals
        refute {"pageview", "/checkout", false} in pages
        refute {"Signup", "", false} in pages

        assert Enum.map(candidates, & &1.visitors) ==
                 candidates |> Enum.map(& &1.visitors) |> Enum.sort(:desc)
      end

      test "filters goals and pages by search term", %{site: site, goals: [_g1, g2, _g3]} do
        populate_stats(site, [
          build(:pageview, pathname: "/sign-in", user_id: 123),
          build(:pageview, pathname: "/checkout", user_id: 123)
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {:ok, candidates} = Stats.Funnel.candidates(site, query, search_term: "sign")

        assert [%{step: %{goal_id: goal_id}}, %{step: %{pathname: "/sign-in"}}] =
                 Enum.sort_by(candidates, & &1.step.is_goal, :desc)

        assert goal_id == g2.id
      end
    end

    describe "funnel/3" do
      test "funnels can be evaluated per site within a time range against an ephemeral definition",
           %{
             site: site,
             goals: [g1, g2, g3 | _]
           } do
        {:ok, funnel_definition} =
          Funnels.ephemeral_definition(
            site,
            "From blog to signup and purchase",
            [
              %{
                "goal_id" => "#{g1.id}",
                "goal" => %{
                  "id" => "#{g1.id}",
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
          )

        populate_stats(site, [
          build(:pageview, pathname: "/irrelevant/page/not/in/funnel", user_id: 999),
          build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
          build(:event, name: "Signup", user_id: 123),
          build(:pageview, pathname: "/checkout", user_id: 123),
          build(:pageview, pathname: "/go/to/blog/bar", user_id: 666),
          build(:event, name: "Signup", user_id: 666)
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        funnel_data = Stats.funnel(site, query, funnel_definition)

        assert {:ok,
                %{
                  all_visitors: 3,
                  entering_visitors: 2,
                  entering_visitors_percentage: "66.67",
                  never_entering_visitors: 1,
                  never_entering_visitors_percentage: "33.33",
                  steps: [
                    %{
                      label: "Visit /go/to/blog/**",
                      visitors: 2,
                      conversion_rate: "100",
                      conversion_rate_step: "0",
                      dropoff: 0,
                      dropoff_percentage: "0"
                    },
                    %{
                      label: "Signup",
                      visitors: 2,
                      conversion_rate: "100",
                      conversion_rate_step: "100",
                      dropoff: 0,
                      dropoff_percentage: "0"
                    },
                    %{
                      label: "Visit /checkout",
                      visitors: 1,
                      conversion_rate: "50",
                      conversion_rate_step: "50",
                      dropoff: 1,
                      dropoff_percentage: "50"
                    }
                  ]
                }} = funnel_data
      end

      test "ephemeral definition creation fails when passed data are invalid", %{site: site} do
        assert {:error, %Ecto.Changeset{valid?: false}} =
                 Funnels.ephemeral_definition(site, "Empty", [])
      end

      test "ephemeral definition creation rejects goals of other sites", %{site: site} do
        other_goal = insert(:goal, site: new_site(), event_name: "Signup")

        assert {:error, :invalid_goal} =
                 Funnels.ephemeral_definition(site, "Foreign", [
                   %{"goal_id" => other_goal.id},
                   %{"page_path" => "/checkout"}
                 ])
      end

      test "ephemeral definition preloads goals of static steps", %{
        site: site,
        goals: [g1 | _]
      } do
        assert {:ok, funnel} =
                 Funnels.ephemeral_definition(site, "Preloaded", [
                   %{"goal_id" => g1.id},
                   %{"page_path" => "/checkout"}
                 ])

        assert [%Plausible.Goal{id: id}, %Plausible.Goal{id: 0}] = Plausible.Funnel.goals(funnel)
        assert id == g1.id
      end

      test "mixed funnels can be evaluated per site within a time range against an ephemeral definition",
           %{
             site: site,
             goals: [g1, g2, g3 | _]
           } do
        {:ok, funnel_definition} =
          Funnels.ephemeral_definition(
            site,
            "From blog to signup and purchase",
            [
              %{
                "goal_id" => "#{g1.id}",
                "goal" => %{
                  "id" => "#{g1.id}",
                  "event_name" => g1.event_name,
                  "page_path" => g1.page_path
                }
              },
              %{"event_name" => g2.event_name},
              %{"page_path" => g3.page_path}
            ]
          )

        populate_stats(site, [
          build(:pageview, pathname: "/irrelevant/page/not/in/funnel", user_id: 999),
          build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
          build(:event, name: "Signup", user_id: 123),
          build(:pageview, pathname: "/checkout", user_id: 123),
          build(:pageview, pathname: "/go/to/blog/bar", user_id: 666),
          build(:event, name: "Signup", user_id: 666)
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        funnel_data = Stats.funnel(site, query, funnel_definition)

        assert {:ok,
                %{
                  all_visitors: 3,
                  entering_visitors: 2,
                  entering_visitors_percentage: "66.67",
                  never_entering_visitors: 1,
                  never_entering_visitors_percentage: "33.33",
                  steps: [
                    %{
                      label: "Visit /go/to/blog/**",
                      visitors: 2,
                      conversion_rate: "100",
                      conversion_rate_step: "0",
                      dropoff: 0,
                      dropoff_percentage: "0"
                    },
                    %{
                      label: "Signup",
                      visitors: 2,
                      conversion_rate: "100",
                      conversion_rate_step: "100",
                      dropoff: 0,
                      dropoff_percentage: "0"
                    },
                    %{
                      label: "Visit /checkout",
                      visitors: 1,
                      conversion_rate: "50",
                      conversion_rate_step: "50",
                      dropoff: 1,
                      dropoff_percentage: "50"
                    }
                  ]
                }} = funnel_data
      end

      test "funnels can be evaluated per site within a time range", %{
        site: site,
        steps: [g1, g2, g3 | _]
      } do
        {:ok, funnel} =
          Funnels.create(
            site,
            "From blog to signup and purchase",
            [g1, g2, g3]
          )

        populate_stats(site, [
          build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
          build(:event, name: "Signup", user_id: 123),
          build(:pageview, pathname: "/checkout", user_id: 123),
          build(:pageview, pathname: "/go/to/blog/bar", user_id: 666),
          build(:event, name: "Signup", user_id: 666)
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        funnel_data = Stats.funnel(site, query, funnel.id)

        assert {:ok,
                %{
                  all_visitors: 2,
                  entering_visitors: 2,
                  entering_visitors_percentage: "100",
                  never_entering_visitors: 0,
                  never_entering_visitors_percentage: "0",
                  steps: [
                    %{
                      label: "Visit /go/to/blog/**",
                      visitors: 2,
                      conversion_rate: "100",
                      conversion_rate_step: "0",
                      dropoff: 0
                    },
                    %{
                      label: "Signup",
                      visitors: 2,
                      conversion_rate: "100",
                      conversion_rate_step: "100",
                      dropoff: 0,
                      dropoff_percentage: "0"
                    },
                    %{
                      label: "Visit /checkout",
                      visitors: 1,
                      conversion_rate: "50",
                      conversion_rate_step: "50",
                      dropoff: 1,
                      dropoff_percentage: "50"
                    }
                  ]
                }} = funnel_data
      end

      test "strict-order funnels stop at intervention events", %{
        site: site,
        steps: [g1, g2, g3 | _]
      } do
        {:ok, non_strict_funnel} =
          Funnels.create(
            site,
            "From blog to signup and purchase",
            [g1, g2, g3]
          )

        {:ok, strict_funnel} =
          Funnels.create(
            site,
            "Strict from blog to signup and purchase",
            [g1, g2, g3],
            funnel_type: :strict
          )

        populate_stats(site, [
          build(:pageview,
            pathname: "/go/to/blog/foo",
            user_id: 123,
            timestamp: ~N[2021-01-01 00:00:00]
          ),
          build(:pageview,
            pathname: "/some/other/page",
            user_id: 123,
            timestamp: ~N[2021-01-01 00:00:01]
          ),
          build(:event,
            name: "Signup",
            user_id: 123,
            timestamp: ~N[2021-01-01 00:00:02]
          ),
          build(:pageview,
            pathname: "/checkout",
            user_id: 123,
            timestamp: ~N[2021-01-01 00:00:03]
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        {:ok, non_strict_funnel_data} = Stats.funnel(site, query, non_strict_funnel.id)
        {:ok, strict_funnel_data} = Stats.funnel(site, query, strict_funnel.id)

        assert Enum.at(non_strict_funnel_data.steps, 2).visitors == 1
        assert Enum.at(strict_funnel_data.steps, 2).visitors == 0

        assert non_strict_funnel_data.funnel_type == :sequential
        assert strict_funnel_data.funnel_type == :strict
      end

      test "flexible funnels count everyone who reaches first and last step in the last step", %{
        site: site,
        steps: [g1, g2, g3 | _]
      } do
        {:ok, non_flexible_funnel} =
          Funnels.create(
            site,
            "From blog to signup and purchase",
            [g1, g2, g3]
          )

        {:ok, flexible_funnel} =
          Funnels.create(
            site,
            "Flexible from blog to signup and purchase",
            [g1, g2, g3],
            funnel_type: :flexible
          )

        populate_stats(site, [
          build(:pageview,
            pathname: "/go/to/blog/foo",
            user_id: 123,
            timestamp: ~N[2021-01-01 00:00:00]
          ),
          build(:pageview,
            pathname: "/checkout",
            user_id: 123,
            timestamp: ~N[2021-01-01 00:00:03]
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        {:ok, non_flexible_funnel_data} = Stats.funnel(site, query, non_flexible_funnel.id)
        {:ok, flexible_funnel_data} = Stats.funnel(site, query, flexible_funnel.id)

        assert Enum.at(non_flexible_funnel_data.steps, 0).visitors == 1
        assert Enum.at(non_flexible_funnel_data.steps, 1).visitors == 0
        assert Enum.at(non_flexible_funnel_data.steps, 2).visitors == 0
        assert Enum.at(flexible_funnel_data.steps, 0).visitors == 1
        assert Enum.at(flexible_funnel_data.steps, 1).visitors == 0
        assert Enum.at(flexible_funnel_data.steps, 2).visitors == 1

        assert non_flexible_funnel_data.funnel_type == :sequential
        assert flexible_funnel_data.funnel_type == :flexible
      end

      test "flexible mixed funnels count everyone who reaches first and last step in the last step",
           %{
             site: site,
             steps: [g1 | _]
           } do
        s2 = %{"event_name" => "Signup"}
        s3 = %{"page_path" => "/checkout"}

        {:ok, non_flexible_funnel} =
          Funnels.create(
            site,
            "From blog to signup and purchase",
            [g1, s2, s3]
          )

        {:ok, flexible_funnel} =
          Funnels.create(
            site,
            "Flexible from blog to signup and purchase",
            [g1, s2, s3],
            funnel_type: :flexible
          )

        populate_stats(site, [
          build(:pageview,
            pathname: "/go/to/blog/foo",
            user_id: 123,
            timestamp: ~N[2021-01-01 00:00:00]
          ),
          build(:pageview,
            pathname: "/checkout",
            user_id: 123,
            timestamp: ~N[2021-01-01 00:00:03]
          )
        ])

        query = QueryBuilder.build!(site, input_date_range: :all)

        {:ok, non_flexible_funnel_data} = Stats.funnel(site, query, non_flexible_funnel.id)
        {:ok, flexible_funnel_data} = Stats.funnel(site, query, flexible_funnel.id)

        assert Enum.at(non_flexible_funnel_data.steps, 0).visitors == 1
        assert Enum.at(non_flexible_funnel_data.steps, 1).visitors == 0
        assert Enum.at(non_flexible_funnel_data.steps, 2).visitors == 0
        assert Enum.at(flexible_funnel_data.steps, 0).visitors == 1
        assert Enum.at(flexible_funnel_data.steps, 1).visitors == 0
        assert Enum.at(flexible_funnel_data.steps, 2).visitors == 1

        assert non_flexible_funnel_data.funnel_type == :sequential
        assert flexible_funnel_data.funnel_type == :flexible
      end

      test "funnels can be evaluated even where there are no visits yet", %{
        site: site,
        steps: [g1, g2, g3 | _]
      } do
        {:ok, funnel} =
          Funnels.create(
            site,
            "From blog to signup and purchase",
            [g1, g2, g3]
          )

        query = QueryBuilder.build!(site, input_date_range: :all)

        funnel_data = Stats.funnel(site, query, funnel.id)

        assert {:ok,
                %{
                  all_visitors: 0,
                  entering_visitors: 0,
                  entering_visitors_percentage: "0",
                  never_entering_visitors: 0,
                  never_entering_visitors_percentage: "0",
                  steps: [
                    %{
                      label: "Visit /go/to/blog/**",
                      visitors: 0,
                      conversion_rate: "0",
                      conversion_rate_step: "0",
                      dropoff: 0,
                      dropoff_percentage: "0"
                    },
                    %{
                      label: "Signup",
                      visitors: 0,
                      conversion_rate: "0",
                      conversion_rate_step: "0",
                      dropoff: 0,
                      dropoff_percentage: "0"
                    },
                    %{
                      label: "Visit /checkout",
                      visitors: 0,
                      conversion_rate: "0",
                      conversion_rate_step: "0",
                      dropoff: 0,
                      dropoff_percentage: "0"
                    }
                  ]
                }} = funnel_data
      end

      @tag :slow
      test "sampling", %{site: site, steps: [g1, g2, g3 | _]} do
        {:ok, funnel} =
          Funnels.create(
            site,
            "From blog to signup and purchase",
            [g1, g2, g3]
          )

        stats =
          1..50_000
          |> Enum.flat_map(fn _ ->
            user_id = SipHash.hash!("0123456789ABCDEF", :crypto.strong_rand_bytes(64))

            [
              build(:pageview, pathname: "/go/to/blog/foo", user_id: user_id),
              build(:event, name: "Signup", user_id: user_id),
              build(:pageview, pathname: "/checkout", user_id: user_id)
            ]
          end)

        populate_stats(site, stats)

        query =
          Plausible.Stats.Query.from(site, %{"period" => "all", "sample_threshold" => "10000"})

        {:ok, funnel_data} = Stats.funnel(site, query, funnel.id)
        assert_in_delta funnel_data[:all_visitors], 50_000, 5000
      end
    end
  end
end
