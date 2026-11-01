defmodule Plausible.BillingTest do
  use Plausible.DataCase
  use Bamboo.Test, shared: true
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing
  alias Plausible.Billing.Subscription
  alias Plausible.Repo

  describe "check_needs_to_upgrade" do
    @describetag :ee_only

    test "is false for a trial user" do
      team = new_user(trial_expiry_date: Date.utc_today()) |> team_of()
      assert Plausible.Teams.Billing.check_needs_to_upgrade(team) == :no_upgrade_needed
    end

    test "is true for a user with an expired trial" do
      team = new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1)) |> team_of()

      assert Plausible.Teams.Billing.check_needs_to_upgrade(team) ==
               {:needs_to_upgrade, :no_active_trial_or_subscription}
    end

    test "is true for a user with empty trial expiry date" do
      assert Plausible.Teams.Billing.check_needs_to_upgrade(nil) ==
               {:needs_to_upgrade, :no_active_trial_or_subscription}
    end

    test "is false for user with empty trial expiry date but with an active subscription" do
      team =
        new_user()
        |> subscribe_to_growth_plan()
        |> team_of()
        |> Ecto.Changeset.change(trial_expiry_date: nil)
        |> Repo.update!()

      assert Plausible.Teams.Billing.check_needs_to_upgrade(team) == :no_upgrade_needed
    end

    test "is false for a user with an expired trial but an active subscription" do
      team =
        new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1))
        |> subscribe_to_growth_plan()
        |> team_of()

      assert Plausible.Teams.Billing.check_needs_to_upgrade(team) == :no_upgrade_needed
    end

    test "is false for a user with a cancelled subscription IF the billing cycle isn't completed yet" do
      team =
        new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1))
        |> subscribe_to_growth_plan(
          status: Subscription.Status.deleted(),
          next_bill_date: Date.utc_today()
        )
        |> team_of()

      assert Plausible.Teams.Billing.check_needs_to_upgrade(team) == :no_upgrade_needed
    end

    test "is true for a user with a cancelled subscription IF the billing cycle is complete" do
      team =
        new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1))
        |> subscribe_to_growth_plan(
          status: Subscription.Status.deleted(),
          next_bill_date: Date.shift(Date.utc_today(), day: -1)
        )
        |> team_of()

      assert Plausible.Teams.Billing.check_needs_to_upgrade(team) ==
               {:needs_to_upgrade, :no_active_trial_or_subscription}
    end

    test "is true for a deleted subscription if no next_bill_date specified" do
      team =
        new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1))
        |> subscribe_to_growth_plan(
          status: Subscription.Status.deleted(),
          next_bill_date: nil
        )
        |> team_of()

      assert Plausible.Teams.Billing.check_needs_to_upgrade(team) ==
               {:needs_to_upgrade, :no_active_trial_or_subscription}
    end

    test "needs to upgrade if subscription active and grace period ended when usage still over limits" do
      user =
        new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1))
        |> subscribe_to_growth_plan(
          status: Subscription.Status.deleted(),
          next_bill_date: Date.utc_today()
        )

      team = user |> team_of() |> Repo.reload!() |> Plausible.Teams.end_grace_period()

      over_limits_usage_stub = monthly_pageview_usage_stub(100_000_000, 100_000_000)

      assert Plausible.Teams.Billing.check_needs_to_upgrade(team, over_limits_usage_stub) ==
               {:needs_to_upgrade, :grace_period_ended}
    end

    test "no upgrade needed if subscription active and grace period ended but usage below limits" do
      user =
        new_user(trial_expiry_date: Date.shift(Date.utc_today(), day: -1))
        |> subscribe_to_growth_plan(
          status: Subscription.Status.deleted(),
          next_bill_date: Date.utc_today()
        )

      team = user |> team_of() |> Repo.reload!() |> Plausible.Teams.end_grace_period()

      assert Plausible.Teams.Billing.check_needs_to_upgrade(team, Plausible.Teams.Billing) ==
               :no_upgrade_needed
    end
  end

  describe "latest_enterprise_plan" do
    test "returns the most recently created enterprise plan of the team" do
      now = NaiveDateTime.utc_now()
      {:ok, team} = Plausible.Teams.get_or_create(new_user())

      insert(:enterprise_plan, team: team, paddle_plan_id: "123", inserted_at: now)

      insert(:enterprise_plan,
        team: team,
        paddle_plan_id: "456",
        inserted_at: NaiveDateTime.shift(now, hour: -10)
      )

      insert(:enterprise_plan,
        team: team,
        paddle_plan_id: "789",
        inserted_at: NaiveDateTime.shift(now, minute: -2)
      )

      assert Billing.latest_enterprise_plan(team).paddle_plan_id == "123"
    end

    test "returns nil when the team has no enterprise plans" do
      {:ok, team} = Plausible.Teams.get_or_create(new_user())
      {:ok, other_team} = Plausible.Teams.get_or_create(new_user())
      insert(:enterprise_plan, team: other_team)

      refute Billing.latest_enterprise_plan(team)
    end
  end

  describe "create_manual_subscription" do
    @describetag :ee_only

    test "creates an active subscription outside of Paddle and relabels the plan" do
      {:ok, team} = Plausible.Teams.get_or_create(new_user())

      plan =
        insert(:enterprise_plan,
          team_id: team.id,
          paddle_plan_id: "123456",
          billing_interval: :yearly
        )

      assert {:ok, _} = Billing.create_manual_subscription(team, plan)

      subscription = Repo.get_by!(Subscription, team_id: team.id)
      today = Date.utc_today()

      assert Subscription.manual_subscription?(subscription)
      assert subscription.status == :active
      assert subscription.paddle_plan_id == "manual-subscription"
      assert is_nil(subscription.paddle_subscription_id)
      assert is_nil(subscription.update_url)
      assert is_nil(subscription.cancel_url)
      assert subscription.currency_code == "XXX"
      assert subscription.next_bill_amount == "-1"
      assert subscription.last_bill_date == today
      assert subscription.next_bill_date == Date.shift(today, year: 1)

      assert Repo.reload!(plan).paddle_plan_id == "manual-subscription"
      assert Plausible.Billing.Plans.get_subscription_plan(subscription).id == plan.id
    end

    test "refuses to subscribe to a plan that is not the latest one" do
      {:ok, team} = Plausible.Teams.get_or_create(new_user())

      older_plan =
        insert(:enterprise_plan,
          team_id: team.id,
          inserted_at: NaiveDateTime.shift(NaiveDateTime.utc_now(), day: -1)
        )

      insert(:enterprise_plan, team_id: team.id)

      assert {:error, :not_latest_plan} = Billing.create_manual_subscription(team, older_plan)

      refute Repo.get_by(Subscription, team_id: team.id)
      refute Repo.reload!(older_plan).paddle_plan_id == "manual-subscription"
    end

    test "returns an error when another plan of the team already has the manual plan ID" do
      {:ok, team} = Plausible.Teams.get_or_create(new_user())

      insert(:enterprise_plan,
        team_id: team.id,
        paddle_plan_id: "manual-subscription",
        inserted_at: NaiveDateTime.shift(NaiveDateTime.utc_now(), day: -1)
      )

      plan = insert(:enterprise_plan, team_id: team.id, billing_interval: :yearly)

      assert {:error, changeset} = Billing.create_manual_subscription(team, plan)
      assert {"has already been taken", _} = changeset.errors[:paddle_plan_id]

      refute Repo.get_by(Subscription, team_id: team.id)
      refute Repo.reload!(plan).paddle_plan_id == "manual-subscription"
    end

    test "refuses to subscribe to a monthly plan" do
      {:ok, team} = Plausible.Teams.get_or_create(new_user())
      plan = insert(:enterprise_plan, team_id: team.id, billing_interval: :monthly)

      assert {:error, :not_yearly} = Billing.create_manual_subscription(team, plan)

      refute Repo.get_by(Subscription, team_id: team.id)
      refute Repo.reload!(plan).paddle_plan_id == "manual-subscription"
    end

    test "refuses to create a second manual subscription" do
      {:ok, team} = Plausible.Teams.get_or_create(new_user())

      # Intentionally preload and make it stale. The function under test
      # should not use the preloaded value as it might be outdated.
      team = Plausible.Teams.with_subscription(team)

      plan = insert(:enterprise_plan, team_id: team.id, billing_interval: :yearly)

      assert {:ok, _} = Billing.create_manual_subscription(team, plan)

      assert {:error, :already_manual} =
               Billing.create_manual_subscription(team, Repo.reload!(plan))

      assert Repo.aggregate(from(s in Subscription, where: s.team_id == ^team.id), :count) == 1
    end

    for status <- [:active, :past_due, :paused] do
      test "refuses when the team has a #{status} Paddle subscription" do
        team = new_user() |> subscribe_to_growth_plan(status: unquote(status)) |> team_of()
        plan = insert(:enterprise_plan, team_id: team.id)

        assert {:error, :active_subscription} = Billing.create_manual_subscription(team, plan)

        refute Subscription.manual_subscription?(Repo.get_by!(Subscription, team_id: team.id))
        refute Repo.reload!(plan).paddle_plan_id == "manual-subscription"
      end
    end

    test "allows replacing a cancelled Paddle subscription" do
      team =
        new_user()
        |> subscribe_to_growth_plan(
          status: :deleted,
          inserted_at: NaiveDateTime.shift(NaiveDateTime.utc_now(), day: -1)
        )
        |> team_of()

      plan = insert(:enterprise_plan, team_id: team.id, billing_interval: :yearly)

      assert {:ok, _} = Billing.create_manual_subscription(team, plan)

      assert Subscription.manual_subscription?(
               Plausible.Teams.with_subscription(team).subscription
             )
    end

    test "allows replacing a legacy free subscription" do
      {:ok, team} = Plausible.Teams.get_or_create(new_user())

      insert(:subscription,
        team: team,
        paddle_plan_id: "free_10k",
        inserted_at: NaiveDateTime.shift(NaiveDateTime.utc_now(), day: -1)
      )

      plan = insert(:enterprise_plan, team_id: team.id, billing_interval: :yearly)

      assert {:ok, _} = Billing.create_manual_subscription(team, plan)

      assert Subscription.manual_subscription?(
               Plausible.Teams.with_subscription(team).subscription
             )
    end
  end

  describe "change_plan" do
    test "sets the next bill amount and date" do
      team = new_user() |> subscribe_to_growth_plan() |> team_of()

      Plausible.Teams.Billing.change_plan(team, "123123")

      subscription = subscription_of(team)
      assert subscription.paddle_plan_id == "123123"
      assert subscription.next_bill_date == ~D[2019-07-10]
      assert subscription.next_bill_amount == "6.00"
    end
  end

  test "active_subscription_for/1 returns active subscription" do
    active_team =
      new_user()
      |> subscribe_to_growth_plan(status: Subscription.Status.active())
      |> team_of()
      |> Plausible.Teams.with_subscription()

    paused_team =
      new_user()
      |> subscribe_to_growth_plan(status: Subscription.Status.paused())
      |> team_of()

    assert Plausible.Teams.Billing.active_subscription_for(active_team).id ==
             active_team.subscription.id

    assert Plausible.Teams.Billing.active_subscription_for(paused_team) == nil
    assert Plausible.Teams.Billing.active_subscription_for(nil) == nil
  end

  test "has_active_subscription?/1 returns whether the user has an active subscription" do
    active_team =
      new_user() |> subscribe_to_growth_plan(status: Subscription.Status.active()) |> team_of()

    paused_team =
      new_user() |> subscribe_to_growth_plan(status: Subscription.Status.paused()) |> team_of()

    assert Plausible.Teams.Billing.has_active_subscription?(active_team)
    refute Plausible.Teams.Billing.has_active_subscription?(paused_team)
    refute Plausible.Teams.Billing.has_active_subscription?(nil)
  end
end
