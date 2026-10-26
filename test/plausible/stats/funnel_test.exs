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

    describe "suggest/3" do
      test "returns empty on no goals and no stats", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {[], []} = Stats.Funnel.suggest(site, query)
      end

      test "returns all goals as unmatched when there are not stats", %{
        site: site,
        goals: [g1, g2, g3 | _]
      } do
        query = QueryBuilder.build!(site, input_date_range: :all)

        assert {[], unmatched} = Stats.Funnel.suggest(site, query, goals: [g1, g2, g3])

        unmatched_ids = Enum.map(unmatched, & &1.id)

        assert length(unmatched_ids) == 3
        assert g1.id in unmatched_ids
        assert g2.id in unmatched_ids
        assert g3.id in unmatched_ids
      end

      test "returns suggestions from stats when no goals provided", %{site: site} do
        query = QueryBuilder.build!(site, input_date_range: :all)

        populate_stats(site, [
          build(:pageview, pathname: "/irrelevant/page/not/in/funnel", user_id: 999),
          build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
          build(:event, name: "Signup", user_id: 123),
          build(:pageview, pathname: "/checkout", user_id: 123),
          build(:pageview, pathname: "/go/to/blog/bar", user_id: 666),
          build(:event, name: "Signup", user_id: 666)
        ])

        assert {suggestions, []} = Stats.Funnel.suggest(site, query)
        suggestions = Enum.map(suggestions, &{&1.event_name, &1.page_path})

        assert length(suggestions) == 6
        assert {"Signup", nil} in suggestions
        assert {nil, "/go/to/blog/foo"} in suggestions
        assert {nil, "/go/to/blog/**"} in suggestions
        assert {nil, "/go/to/blog/bar"} in suggestions
        assert {nil, "/checkout"} in suggestions
        assert {nil, "/irrelevant/page/not/in/funnel"} in suggestions
      end

      test "returns only unmatched goals", %{site: site, goals: [g1, g2, g3 | _]} do
        {:ok, g4} = Goals.create(site, %{"event_name" => "Unmatched"})
        query = QueryBuilder.build!(site, input_date_range: :all)

        populate_stats(site, [
          build(:pageview, pathname: "/irrelevant/page/not/in/funnel", user_id: 999),
          build(:pageview, pathname: "/go/to/blog/foo", user_id: 123),
          build(:event, name: "Signup", user_id: 123),
          build(:pageview, pathname: "/checkout", user_id: 123),
          build(:pageview, pathname: "/go/to/blog/bar", user_id: 666),
          build(:event, name: "Signup", user_id: 666)
        ])

        assert {suggestions, [unmatched]} =
                 Stats.Funnel.suggest(site, query, goals: [g1, g2, g3, g4])

        suggestions = Enum.map(suggestions, &{&1.event_name, &1.page_path})

        assert length(suggestions) == 6
        assert {"Signup", nil} in suggestions
        assert {nil, "/go/to/blog/foo"} in suggestions
        assert {nil, "/go/to/blog/**"} in suggestions
        assert {nil, "/go/to/blog/bar"} in suggestions
        assert {nil, "/checkout"} in suggestions
        assert {nil, "/irrelevant/page/not/in/funnel"} in suggestions

        assert unmatched.event_name == "Unmatched"
      end
    end

    describe "funnel/3" do
      test "funnels can be evaluated per site within a time range against an ephemeral definition",
           %{
             site: site,
             goals: [g1, g2, g3 | _]
           } do
        funnel_definition =
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
            ],
            allowed_goal_ids: [g1.id, g2.id, g3.id]
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

      test "ephemeral definition creation crashes when passed data are invalid", %{site: site} do
        assert_raise MatchError, fn ->
          Funnels.ephemeral_definition(site, "Empty", [])
        end
      end

      test "mixed funnels can be evaluated per site within a time range against an ephemeral definition",
           %{
             site: site,
             goals: [g1, g2, g3 | _]
           } do
        funnel_definition =
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
            ],
            allowed_goal_ids: [g1.id, g2.id, g3.id]
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
