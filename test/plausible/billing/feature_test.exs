defmodule Plausible.Billing.FeatureTest do
  use Plausible.DataCase
  use Plausible.Teams.Test

  @v1_plan_id "558018"

  for mod <- [Plausible.Billing.Feature.Funnels, Plausible.Billing.Feature.RevenueGoals] do
    test "#{mod}.check_availability/1 returns :ok when site owner is on a enterprise plan" do
      user =
        new_user()
        |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [unquote(mod)])

      assert :ok == unquote(mod).check_availability(user)
    end

    test "#{mod}.check_availability/1 returns :ok when site owner is on a business plan" do
      user = new_user() |> subscribe_to_business_plan()
      assert :ok == unquote(mod).check_availability(user)
    end

    test "#{mod}.check_availability/1 returns error when site owner is on a growth plan" do
      user = new_user() |> subscribe_to_growth_plan()
      assert {:error, :upgrade_required} == unquote(mod).check_availability(user)
    end

    test "#{mod}.check_availability/1 returns error when site owner is on an old plan" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))
      assert {:error, :upgrade_required} == unquote(mod).check_availability(user)
    end
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user is on a business plan" do
    user = new_user() |> subscribe_to_business_plan()
    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user is on an old plan" do
    user = new_user() |> subscribe_to_plan(@v1_plan_id)
    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user is on trial" do
    user = new_user()
    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user is on an enterprise plan" do
    user =
      new_user()
      |> subscribe_to_enterprise_plan(
        paddle_plan_id: "123321",
        features: [Plausible.Billing.Feature.StatsAPI]
      )

    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  @tag :ee_only
  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns error when user is on a growth plan" do
    user = new_user() |> subscribe_to_growth_plan()

    assert {:error, :upgrade_required} ==
             Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok when user trial hasn't started and was created before the business tier launch" do
    user = new_user(inserted_at: ~N[2020-01-01T00:00:00], trial_expiry_date: nil)
    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns :ok if user is subscribed and account was created after business tier launch" do
    user = new_user(trial_expiry_date: nil) |> subscribe_to_business_plan()
    assert :ok == Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  @tag :ee_only
  test "Plausible.Billing.Feature.StatsAPI.check_availability/2 returns error when user trial hasn't started and was created after the business tier launch" do
    user = new_user(trial_expiry_date: nil)

    assert {:error, :upgrade_required} ==
             Plausible.Billing.Feature.StatsAPI.check_availability(user)
  end

  test "Plausible.Billing.Feature.Props.check_availability/1 applies grandfathering to old plans" do
    user = new_user() |> subscribe_to_plan(@v1_plan_id)
    assert :ok == Plausible.Billing.Feature.Props.check_availability(user)
  end

  test "Plausible.Billing.Feature.Goals.check_availability/2 always returns :ok" do
    u1 = new_user() |> subscribe_to_plan(@v1_plan_id)
    u2 = new_user() |> subscribe_to_growth_plan()
    u3 = new_user() |> subscribe_to_business_plan()
    u4 = new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: "123321")

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
      user = new_user()
      site = new_site([{:owner, user}, {unquote(property), false}])

      {:ok, site} = unquote(mod).toggle(site, user)
      assert Map.get(site, unquote(property))
      assert unquote(mod).enabled?(site)
      refute unquote(mod).opted_out?(site)

      {:ok, site} = unquote(mod).toggle(site, user)
      refute Map.get(site, unquote(property))
      refute unquote(mod).enabled?(site)
      assert unquote(mod).opted_out?(site)
    end

    test "#{mod}.toggle/2 accepts an override option" do
      user = new_user()
      site = new_site([{:owner, user}, {unquote(property), false}])

      {:ok, site} = unquote(mod).toggle(site, user, override: false)
      refute Map.get(site, unquote(property))
      refute unquote(mod).enabled?(site)
    end

    test "#{mod}.toggle/2 errors when enabling a feature the site owner does not have access to the feature" do
      user = new_user() |> subscribe_to_growth_plan()
      site = new_site([{:owner, user}, {unquote(property), false}])

      {:error, :upgrade_required} = unquote(mod).toggle(site, user)
      refute unquote(mod).enabled?(site)
    end

    test "#{mod}.toggle/2 does not error when disabling a feature the site owner does not have access to" do
      user = new_user() |> subscribe_to_growth_plan()
      site = new_site([{:owner, user}, {unquote(property), true}])

      {:ok, site} = unquote(mod).toggle(site, user)
      assert unquote(mod).opted_out?(site)
    end
  end

  test "Plausible.Billing.Feature.Goals.toggle/2 toggles conversions_enabled on and off" do
    user = new_user()
    site = new_site(owner: user, conversions_enabled: false)

    {:ok, site} = Plausible.Billing.Feature.Goals.toggle(site, user)
    assert Map.get(site, :conversions_enabled)
    assert Plausible.Billing.Feature.Goals.enabled?(site)
    refute Plausible.Billing.Feature.Goals.opted_out?(site)

    {:ok, site} = Plausible.Billing.Feature.Goals.toggle(site, user)
    refute Map.get(site, :conversions_enabled)
    refute Plausible.Billing.Feature.Goals.enabled?(site)
    assert Plausible.Billing.Feature.Goals.opted_out?(site)
  end

  for mod <- [Plausible.Billing.Feature.Funnels, Plausible.Billing.Feature.Props] do
    test "#{mod}.enabled?/1 returns false when user does not have access to the feature even when enabled" do
      user = new_user() |> subscribe_to_growth_plan()
      site = new_site([{:owner, user}, {unquote(mod).toggle_field(), true}])
      refute unquote(mod).enabled?(site)
    end

    test "#{mod}.opted_out?/1 returns false when feature toggle is enabled even when user does not have access to the feature" do
      user = new_user() |> subscribe_to_growth_plan()
      site = new_site([{:owner, user}, {unquote(mod).toggle_field(), true}])
      refute unquote(mod).opted_out?(site)
    end
  end
end
