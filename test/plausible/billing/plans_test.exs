defmodule Plausible.Billing.PlansTest do
  use Plausible.DataCase, async: true
  alias Plausible.Billing.Plans

  @legacy_plan_id "558746"
  @v1_plan_id "558018"
  @v2_plan_id "654177"
  @v3_business_plan_id "857481"

  describe "getting subscription plans for user" do
    test "growth_plans_for/1 returns v1 plans for a user on a legacy plan" do
      insert(:user, subscription: build(:subscription, paddle_plan_id: @legacy_plan_id))
      |> Plans.growth_plans_for()
      |> assert_generation(1)
    end

    test "growth_plans_for/1 returns v1 plans for users who are already on v1 pricing" do
      insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      |> Plans.growth_plans_for()
      |> assert_generation(1)
    end

    test "growth_plans_for/1 returns v2 plans for users who are already on v2 pricing" do
      insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))
      |> Plans.growth_plans_for()
      |> assert_generation(2)
    end

    test "growth_plans_for/1 returns v4 plans for invited users with trial_expiry = nil" do
      insert(:user, trial_expiry_date: nil)
      |> Plans.growth_plans_for()
      |> assert_generation(4)
    end

    test "growth_plans_for/1 returns v4 plans for users whose trial started after the business tiers release" do
      insert(:user, trial_expiry_date: ~D[2023-12-24])
      |> Plans.growth_plans_for()
      |> assert_generation(4)
    end

    test "growth_plans_for/1 returns v4 plans for expired legacy subscriptions" do
      subscription =
        build(:subscription,
          paddle_plan_id: @v1_plan_id,
          status: :deleted,
          next_bill_date: ~D[2023-11-10]
        )

      insert(:user, subscription: subscription)
      |> Plans.growth_plans_for()
      |> assert_generation(4)
    end

    test "growth_plans_for/1 shows v4 plans for everyone else" do
      insert(:user)
      |> Plans.growth_plans_for()
      |> assert_generation(4)
    end

    test "growth_plans_for/1 does not return business plans" do
      insert(:user)
      |> Plans.growth_plans_for()
      |> Enum.each(fn plan ->
        assert plan.kind != :business
      end)
    end

    test "growth_plans_for/1 returns the latest generation of growth plans for a user with a business subscription" do
      insert(:user, subscription: build(:subscription, paddle_plan_id: @v3_business_plan_id))
      |> Plans.growth_plans_for()
      |> assert_generation(4)
    end

    test "business_plans_for/1 returns v3 business plans for a user on a legacy plan" do
      insert(:user, subscription: build(:subscription, paddle_plan_id: @legacy_plan_id))
      |> Plans.business_plans_for()
      |> assert_generation(3)
    end

    test "business_plans_for/1 returns v3 business plans for a v2 subscriber" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))

      business_plans = Plans.business_plans_for(user)

      assert Enum.all?(business_plans, &(&1.kind == :business))
      assert_generation(business_plans, 3)
    end

    test "business_plans_for/1 returns v4 plans for invited users with trial_expiry = nil" do
      insert(:user, trial_expiry_date: nil)
      |> Plans.business_plans_for()
      |> assert_generation(4)
    end

    test "business_plans_for/1 returns v4 plans for users whose trial started after the business tiers release" do
      insert(:user, trial_expiry_date: ~D[2023-12-24])
      |> Plans.business_plans_for()
      |> assert_generation(4)
    end

    test "business_plans_for/1 returns v4 plans for expired legacy subscriptions" do
      subscription =
        build(:subscription,
          paddle_plan_id: @v2_plan_id,
          status: :deleted,
          next_bill_date: ~D[2023-11-10]
        )

      insert(:user, subscription: subscription)
      |> Plans.business_plans_for()
      |> assert_generation(4)
    end

    test "business_plans_for/1 returns v4 business plans for everyone else" do
      user = insert(:user)
      business_plans = Plans.business_plans_for(user)

      assert Enum.all?(business_plans, &(&1.kind == :business))
      assert_generation(business_plans, 4)
    end

    test "available_plans returns all plans for user with prices when asked for" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))

      %{growth: growth_plans, business: business_plans} =
        Plans.available_plans_for(user, with_prices: true)

      assert Enum.find(growth_plans, fn plan ->
               (%Money{} = plan.monthly_cost) && plan.monthly_product_id == @v2_plan_id
             end)

      assert Enum.find(business_plans, fn plan ->
               (%Money{} = plan.monthly_cost) && plan.monthly_product_id == @v3_business_plan_id
             end)
    end

    test "available_plans returns all plans without prices by default" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v2_plan_id))

      assert %{growth: [_ | _], business: [_ | _]} = Plans.available_plans_for(user)
    end

    test "latest_enterprise_plan_with_price/1" do
      user = insert(:user)
      insert(:enterprise_plan, user: user, paddle_plan_id: "123", inserted_at: Timex.now())

      insert(:enterprise_plan,
        user: user,
        paddle_plan_id: "456",
        inserted_at: Timex.shift(Timex.now(), hours: -10)
      )

      insert(:enterprise_plan,
        user: user,
        paddle_plan_id: "789",
        inserted_at: Timex.shift(Timex.now(), minutes: -2)
      )

      {enterprise_plan, price} = Plans.latest_enterprise_plan_with_price(user)

      assert enterprise_plan.paddle_plan_id == "123"
      assert price == Money.new(:EUR, "10.0")
    end
  end

  describe "subscription_interval" do
    test "is based on the plan if user is on a standard plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert Plans.subscription_interval(user.subscription) == "monthly"
    end

    test "is N/A for free plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      assert Plans.subscription_interval(user.subscription) == "N/A"
    end

    test "is based on the enterprise plan if user is on an enterprise plan" do
      user = insert(:user)

      enterprise_plan = insert(:enterprise_plan, user_id: user.id, billing_interval: :yearly)

      subscription =
        insert(:subscription, user_id: user.id, paddle_plan_id: enterprise_plan.paddle_plan_id)

      assert Plans.subscription_interval(subscription) == :yearly
    end
  end

  describe "suggested_plan/2" do
    test "returns suggested plan based on usage" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert %Plausible.Billing.Plan{
               monthly_pageview_limit: 100_000,
               monthly_cost: nil,
               monthly_product_id: "558745",
               volume: "100k",
               yearly_cost: nil,
               yearly_product_id: "590752"
             } = Plans.suggest(user, 10_000)

      assert %Plausible.Billing.Plan{
               monthly_pageview_limit: 200_000,
               monthly_cost: nil,
               monthly_product_id: "597485",
               volume: "200k",
               yearly_cost: nil,
               yearly_product_id: "597486"
             } = Plans.suggest(user, 100_000)
    end

    test "returns nil when user has enterprise-level usage" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      assert :enterprise == Plans.suggest(user, 100_000_000)
    end

    test "returns nil when user is on an enterprise plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      _enterprise_plan = insert(:enterprise_plan, user_id: user.id, billing_interval: :yearly)
      assert :enterprise == Plans.suggest(user, 10_000)
    end
  end

  describe "yearly_product_ids/0" do
    test "lists yearly plan ids" do
      assert [
               "590753",
               "648089",
               "572810",
               "590752",
               "597486",
               "597488",
               "597643",
               "597310",
               "597312",
               "642354",
               "642356",
               "650653",
               "653232",
               "653234",
               "653236",
               "653239",
               "653242",
               "653254",
               "653256",
               "653257",
               "653258",
               "653259",
               "749343",
               "749345",
               "749347",
               "749349",
               "749352",
               "749355",
               "749357",
               "749359",
               "857482",
               "857484",
               "857487",
               "857491",
               "857494",
               "857496",
               "857500",
               "857502",
               "857079",
               "857080",
               "857081",
               "857082",
               "857083",
               "857084",
               "857085",
               "857086",
               "857087",
               "857088",
               "857089",
               "857090",
               "857091",
               "857092",
               "857093",
               "857094"
             ] == Plans.yearly_product_ids()
    end
  end

  describe "suggest_tier/1" do
    test "suggests Business when user has used a premium feature" do
      user = insert(:user)
      insert(:api_key, user: user)

      assert Plans.suggest_tier(user) == :business
    end

    test "suggests Growth when no premium features used" do
      user = insert(:user)
      site = insert(:site, members: [user])
      insert(:goal, site: site, event_name: "goals_is_not_premium")

      assert Plans.suggest_tier(user) == :growth
    end

    test "suggests Growth tier for a user who used the Stats API, but signed up before it was considered a premium feature" do
      user = insert(:user, inserted_at: ~N[2023-10-25 10:00:00])
      insert(:api_key, user: user)

      assert Plans.suggest_tier(user) == :growth
    end

    @tag :full_build_only
    test "suggests Business tier for a user who used the Revenue Goals, even when they signed up before Business tier release" do
      user = insert(:user, inserted_at: ~N[2023-10-25 10:00:00])
      site = insert(:site, members: [user])
      insert(:goal, site: site, currency: :USD, event_name: "Purchase")

      assert Plans.suggest_tier(user) == :business
    end
  end

  defp assert_generation(plans_list, generation) do
    assert List.first(plans_list).generation == generation
  end
end
