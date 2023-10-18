defmodule Plausible.Billing.FeatureTest do
  use Plausible.DataCase

  @v1_plan_id "558018"

  for mod <- [Plausible.Billing.Feature.Funnels, Plausible.Billing.Feature.RevenueGoals] do
    test "#{mod}.check_availability/1 returns :ok when site owner is on a enterprise plan" do
      user =
        insert(:user,
          enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
          subscription: build(:subscription, paddle_plan_id: "123321")
        )

      assert :ok == unquote(mod).check_availability(user)
    end

    test "#{mod}.check_availability/1 returns :ok when site owner is on a business plan" do
      user = insert(:user, subscription: build(:business_subscription))

      assert :ok == unquote(mod).check_availability(user)
    end

    test "#{mod}.check_availability/1 returns error when site owner is on a growth plan" do
      user = insert(:user, subscription: build(:growth_subscription))
      assert {:error, :upgrade_required} == unquote(mod).check_availability(user)
    end

    test "#{mod}.check_availability/1 returns error when site owner is on an old plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      assert {:error, :upgrade_required} == unquote(mod).check_availability(user)
    end
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user is on a business plan" do
    user = insert(:user, subscription: build(:business_subscription))
    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user is on an old plan" do
    user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user is on trial" do
    user = insert(:user)
    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user is on an enterprise plan" do
    user =
      insert(:user,
        enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
        subscription: build(:subscription, paddle_plan_id: "123321")
      )

    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns error when user is on a growth plan" do
    user = insert(:user, subscription: build(:growth_subscription))

    assert {:error, :upgrade_required} ==
             Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.Props.check_availability/1 applies grandfathering to old plans" do
    user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
    assert :ok == Plausible.Billing.Feature.Props.check_availability(user)
  end

  test "Plausible.Billing.Feature.Goals.check_availability/2 always returns :ok" do
    u1 = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
    u2 = insert(:user, subscription: build(:growth_subscription))
    u3 = insert(:user, subscription: build(:business_subscription))

    u4 =
      insert(:user,
        enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
        subscription: build(:subscription, paddle_plan_id: "123321")
      )

    assert :ok == Plausible.Billing.Feature.Goals.check_availability(u1)
    assert :ok == Plausible.Billing.Feature.Goals.check_availability(u2)
    assert :ok == Plausible.Billing.Feature.Goals.check_availability(u3)
    assert :ok == Plausible.Billing.Feature.Goals.check_availability(u4)
  end

  for {mod, property} <- [
        {Plausible.Billing.Feature.Funnels, :funnels_enabled},
        {Plausible.Billing.Feature.Props, :props_enabled}
      ] do
    test "#{mod}.toggle/2 toggles #{property} on and off" do
      site = insert(:site, [{:members, [build(:user)]}, {unquote(property), false}])

      {:ok, site} = unquote(mod).toggle(site)
      assert Map.get(site, unquote(property))
      assert unquote(mod).enabled?(site)

      {:ok, site} = unquote(mod).toggle(site)
      refute Map.get(site, unquote(property))
      refute unquote(mod).enabled?(site)
    end

    test "#{mod}.toggle/2 accepts an override option" do
      site = insert(:site, [{:members, [build(:user)]}, {unquote(property), false}])

      {:ok, site} = unquote(mod).toggle(site, override: false)
      refute Map.get(site, unquote(property))
      refute unquote(mod).enabled?(site)
    end

    test "#{mod}.toggle/2 errors when site owner does not have access to the feature" do
      user = insert(:user, subscription: build(:growth_subscription))
      site = insert(:site, [{:members, [user]}, {unquote(property), false}])
      {:error, :upgrade_required} = unquote(mod).toggle(site)
      refute unquote(mod).enabled?(site)
    end
  end

  test "Plausible.Billing.Feature.Goals.toggle/2 toggles conversions_enabled on and off" do
    site = insert(:site, [{:members, [build(:user)]}, {:conversions_enabled, false}])

    {:ok, site} = Plausible.Billing.Feature.Goals.toggle(site)
    assert Map.get(site, :conversions_enabled)
    assert Plausible.Billing.Feature.Goals.enabled?(site)

    {:ok, site} = Plausible.Billing.Feature.Goals.toggle(site)
    refute Map.get(site, :conversions_enabled)
    refute Plausible.Billing.Feature.Goals.enabled?(site)
  end

  for mod <- [Plausible.Billing.Feature.Funnels, Plausible.Billing.Feature.Props] do
    test "#{mod}.enabled?/1 returns false when user does not have access to the feature even when enabled" do
      user = insert(:user, subscription: build(:growth_subscription))
      site = insert(:site, [{:members, [user]}, {unquote(mod).toggle_field(), true}])
      refute unquote(mod).enabled?(site)
    end
  end
end
