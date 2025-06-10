defmodule Plausible.Billing.FeatureTest do
  alias Plausible.Billing.Feature.SiteSegments
  use Plausible.DataCase
  use Plausible.Teams.Test

  alias Plausible.Billing.Feature.{
    Goals,
    SiteSegments,
    SharedLinks,
    Funnels,
    RevenueGoals,
    StatsAPI,
    Props
  }

  @v1_growth_plan_id "558018"
  @v5_growth_plan_id "910429"

  describe "business features (for everyone)" do
    for mod <- [Funnels, RevenueGoals] do
      test "#{mod}.check_availability/1 returns :ok when site owner is on a enterprise plan that supports #{mod}" do
        team =
          new_user()
          |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [unquote(mod)])
          |> team_of()

        assert :ok == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns error when site owner is on a enterprise plan does not support #{mod}" do
        team =
          new_user()
          |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [Goals])
          |> team_of()

        assert {:error, :upgrade_required} == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns :ok when site owner is on a business plan" do
        team = new_user() |> subscribe_to_business_plan() |> team_of()
        assert :ok == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns error when site owner is on a growth plan" do
        team = new_user() |> subscribe_to_growth_plan() |> team_of()
        assert {:error, :upgrade_required} == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns error when site owner is on an old v1 plan" do
        team = new_user() |> subscribe_to_plan(@v1_growth_plan_id) |> team_of()
        assert {:error, :upgrade_required} == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns :ok when user is on trial" do
        team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
        assert :ok == unquote(mod).check_availability(team)
      end
    end
  end

  describe "business features (grandfathered Growth access before v4)" do
    for mod <- [Props, StatsAPI] do
      test "#{mod}.check_availability/1 returns :ok when site owner is on a enterprise plan that supports #{mod}" do
        team =
          new_user()
          |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [unquote(mod)])
          |> team_of()

        assert :ok == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns error when site owner is on a enterprise plan does not support #{mod}" do
        team =
          new_user()
          |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [Goals])
          |> team_of()

        assert {:error, :upgrade_required} == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns :ok when site owner is on a business plan" do
        team = new_user() |> subscribe_to_business_plan() |> team_of()
        assert :ok == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns error when site owner is on a new growth plan" do
        team = new_user() |> subscribe_to_growth_plan() |> team_of()
        assert {:error, :upgrade_required} == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns :ok when site owner is on an old plan" do
        team = new_user() |> subscribe_to_plan(@v1_growth_plan_id) |> team_of()
        assert :ok == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns :ok when user is on trial" do
        team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
        assert :ok == unquote(mod).check_availability(team)
      end
    end
  end

  describe "growth features" do
    for mod <- [SharedLinks, SiteSegments] do
      test "#{mod}.check_availability/1 returns :ok when site owner is on a enterprise plan that supports #{mod}" do
        team =
          new_user()
          |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [unquote(mod)])
          |> team_of()

        assert :ok == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns error when site owner is on a enterprise plan does not support #{mod}" do
        team =
          new_user()
          |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [Goals])
          |> team_of()

        assert {:error, :upgrade_required} == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns :ok when site owner is on a business plan" do
        team = new_user() |> subscribe_to_business_plan() |> team_of()
        assert :ok == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns :ok when site owner is on a growth plan" do
        team = new_user() |> subscribe_to_plan(@v5_growth_plan_id) |> team_of()
        assert :ok == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns error when site owner is on a starter plan" do
        team = new_user() |> subscribe_to_starter_plan() |> team_of()
        assert {:error, :upgrade_required} == unquote(mod).check_availability(team)
      end

      test "#{mod}.check_availability/1 returns :ok when user is on trial" do
        team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
        assert :ok == unquote(mod).check_availability(team)
      end
    end
  end

  test "Goals.check_availability/2 always returns :ok" do
    t1 = new_user() |> subscribe_to_plan(@v1_growth_plan_id) |> team_of()
    t2 = new_user() |> subscribe_to_growth_plan() |> team_of()
    t3 = new_user() |> subscribe_to_business_plan() |> team_of()
    t4 = new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: "123321") |> team_of()

    assert :ok == Goals.check_availability(t1)
    assert :ok == Goals.check_availability(t2)
    assert :ok == Goals.check_availability(t3)
    assert :ok == Goals.check_availability(t4)
  end

  for {mod, property} <- [
        {Funnels, :funnels_enabled},
        {Props, :props_enabled}
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
