defmodule Plausible.FunnelsCustomPropsGoals do
  use Plausible.DataCase
  @moduletag :ee_only

  on_ee do
    alias Plausible.Goals
    alias Plausible.Funnels
    alias Plausible.Stats
    alias Plausible.Stats.{QueryBuilder, ParsedQueryParams}

    describe "Plausible.Stats.Funnel - with custom property goals" do
      setup do
        site = new_site()
        {:ok, site: site}
      end

      test "funnels with custom property filters on event goals", %{site: site} do
        {:ok, g1} = Goals.create(site, %{"page_path" => "/start"})

        {:ok, g2} =
          Goals.create(site, %{
            "event_name" => "Purchase",
            "custom_props" => %{"plan" => "premium"}
          })

        {:ok, g3} = Goals.create(site, %{"page_path" => "/thank-you"})

        {:ok, funnel} =
          Funnels.create(
            site,
            "Premium purchase funnel",
            [
              %{"goal_id" => g1.id},
              %{"goal_id" => g2.id},
              %{"goal_id" => g3.id}
            ]
          )

        populate_stats(site, [
          build(:pageview, pathname: "/start", user_id: 100),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan"],
            "meta.value": ["premium"],
            user_id: 100
          ),
          build(:pageview, pathname: "/thank-you", user_id: 100),
          build(:pageview, pathname: "/start", user_id: 200),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan"],
            "meta.value": ["free"],
            user_id: 200
          ),
          build(:pageview, pathname: "/thank-you", user_id: 200),
          build(:pageview, pathname: "/start", user_id: 300),
          build(:event, name: "Purchase", user_id: 300)
        ])

        query = QueryBuilder.build!(site, %ParsedQueryParams{input_date_range: :all})

        {:ok, funnel_data} = Stats.funnel(site, query, funnel.id)

        assert funnel_data[:all_visitors] == 3
        assert funnel_data[:entering_visitors] == 3

        assert [step1, step2, step3] = funnel_data[:steps]
        assert step1.visitors == 3
        assert step2.visitors == 1
        assert step3.visitors == 1
      end

      test "funnels with multiple custom property filters", %{site: site} do
        {:ok, g1} = Goals.create(site, %{"event_name" => "Start"})

        {:ok, g2} =
          Goals.create(site, %{
            "event_name" => "Purchase",
            "custom_props" => %{"plan" => "premium", "variant" => "A"}
          })

        {:ok, funnel} =
          Funnels.create(
            site,
            "Premium variant A funnel",
            [
              %{"goal_id" => g1.id},
              %{"goal_id" => g2.id}
            ]
          )

        populate_stats(site, [
          build(:event, name: "Start", user_id: 100),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan", "variant"],
            "meta.value": ["premium", "A"],
            user_id: 100
          ),
          build(:event, name: "Start", user_id: 200),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan", "variant"],
            "meta.value": ["premium", "B"],
            user_id: 200
          ),
          build(:event, name: "Start", user_id: 300),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan", "variant"],
            "meta.value": ["free", "A"],
            user_id: 300
          ),
          build(:event, name: "Start", user_id: 400),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan"],
            "meta.value": ["premium"],
            user_id: 400
          )
        ])

        query = QueryBuilder.build!(site, %ParsedQueryParams{input_date_range: :all})

        {:ok, funnel_data} = Stats.funnel(site, query, funnel.id)

        assert funnel_data[:all_visitors] == 4
        assert funnel_data[:entering_visitors] == 4

        assert [step1, step2] = funnel_data[:steps]
        assert step1.visitors == 4
        assert step2.visitors == 1
      end

      test "funnels with mixed goals (custom props and regular)", %{site: site} do
        {:ok, g1} =
          Goals.create(site, %{
            "event_name" => "Signup",
            "custom_props" => %{"method" => "email"}
          })

        {:ok, g2} = Goals.create(site, %{"event_name" => "Onboarding Complete"})

        {:ok, g3} =
          Goals.create(site, %{
            "event_name" => "Purchase",
            "custom_props" => %{"plan" => "premium"}
          })

        {:ok, funnel} =
          Funnels.create(
            site,
            "Email signup to premium purchase",
            [
              %{"goal_id" => g1.id},
              %{"goal_id" => g2.id},
              %{"goal_id" => g3.id}
            ]
          )

        populate_stats(site, [
          build(:event,
            name: "Signup",
            "meta.key": ["method"],
            "meta.value": ["email"],
            user_id: 100
          ),
          build(:event, name: "Onboarding Complete", user_id: 100),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan"],
            "meta.value": ["premium"],
            user_id: 100
          ),
          build(:event,
            name: "Signup",
            "meta.key": ["method"],
            "meta.value": ["google"],
            user_id: 200
          ),
          build(:event, name: "Onboarding Complete", user_id: 200),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan"],
            "meta.value": ["premium"],
            user_id: 200
          ),
          build(:event,
            name: "Signup",
            "meta.key": ["method"],
            "meta.value": ["email"],
            user_id: 300
          ),
          build(:event, name: "Onboarding Complete", user_id: 300),
          build(:event,
            name: "Purchase",
            "meta.key": ["plan"],
            "meta.value": ["free"],
            user_id: 300
          )
        ])

        query = QueryBuilder.build!(site, %ParsedQueryParams{input_date_range: :all})

        {:ok, funnel_data} = Stats.funnel(site, query, funnel.id)

        assert funnel_data[:all_visitors] == 3
        assert funnel_data[:entering_visitors] == 2

        assert [step1, step2, step3] = funnel_data[:steps]
        assert step1.visitors == 2
        assert step2.visitors == 2
        assert step3.visitors == 1
      end

      test "funnel with empty custom_props does not filter", %{site: site} do
        {:ok, g1} =
          Goals.create(site, %{
            "event_name" => "Click",
            "custom_props" => %{}
          })

        {:ok, g2} = Goals.create(site, %{"event_name" => "Convert"})

        {:ok, funnel} =
          Funnels.create(
            site,
            "Click to convert funnel",
            [
              %{"goal_id" => g1.id},
              %{"goal_id" => g2.id}
            ]
          )

        populate_stats(site, [
          build(:event, name: "Click", user_id: 100),
          build(:event, name: "Convert", user_id: 100),
          build(:event,
            name: "Click",
            "meta.key": ["button"],
            "meta.value": ["cta"],
            user_id: 200
          ),
          build(:event, name: "Convert", user_id: 200)
        ])

        query = QueryBuilder.build!(site, %ParsedQueryParams{input_date_range: :all})

        {:ok, funnel_data} = Stats.funnel(site, query, funnel.id)

        assert funnel_data[:all_visitors] == 2
        assert funnel_data[:entering_visitors] == 2

        assert [step1, step2] = funnel_data[:steps]
        assert step1.visitors == 2
        assert step2.visitors == 2
      end
    end
  end
end
