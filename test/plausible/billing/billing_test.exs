defmodule Plausible.BillingTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  use Bamboo.Test, shared: true
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing
  alias Plausible.Billing.Subscription

  describe "check_needs_to_upgrade" do
    test "is false for a trial user" do
      user = insert(:user)
      assert Billing.check_needs_to_upgrade(user) == :no_upgrade_needed
    end

    test "is true for a user with an expired trial" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))

      assert Billing.check_needs_to_upgrade(user) == {:needs_to_upgrade, :no_active_subscription}
    end

    test "is true for a user with empty trial expiry date" do
      user = insert(:user, trial_expiry_date: nil)

      assert Billing.check_needs_to_upgrade(user) == {:needs_to_upgrade, :no_trial}
    end

    test "is false for user with empty trial expiry date but with an active subscription" do
      user = insert(:user, trial_expiry_date: nil)
      insert(:subscription, user: user)

      assert Billing.check_needs_to_upgrade(user) == :no_upgrade_needed
    end

    test "is false for a user with an expired trial but an active subscription" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))
      insert(:subscription, user: user)

      assert Billing.check_needs_to_upgrade(user) == :no_upgrade_needed
    end

    test "is false for a user with a cancelled subscription IF the billing cycle isn't completed yet" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))

      insert(:subscription,
        user: user,
        status: Subscription.Status.deleted(),
        next_bill_date: Timex.today()
      )

      assert Billing.check_needs_to_upgrade(user) == :no_upgrade_needed
    end

    test "is true for a user with a cancelled subscription IF the billing cycle is complete" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))

      insert(:subscription,
        user: user,
        status: Subscription.Status.deleted(),
        next_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      assert Billing.check_needs_to_upgrade(user) == {:needs_to_upgrade, :no_active_subscription}
    end

    test "is true for a deleted subscription if no next_bill_date specified" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))

      insert(:subscription,
        user: user,
        status: Subscription.Status.deleted(),
        next_bill_date: nil
      )

      assert Billing.check_needs_to_upgrade(user) == {:needs_to_upgrade, :no_active_subscription}
    end

    test "is true for a user past their grace period" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))
      insert(:subscription, user: user, next_bill_date: Timex.today())

      user = Plausible.Users.end_grace_period(user)

      assert Billing.check_needs_to_upgrade(user) == {:needs_to_upgrade, :grace_period_ended}
    end
  end

  @subscription_id "subscription-123"
  @plan_id_10k "654177"
  @plan_id_100k "654178"

  @subscription_created_params %{
    "event_time" => "2019-05-01 01:03:52",
    "alert_name" => "subscription_created",
    "passthrough" => "",
    "email" => "",
    "subscription_id" => @subscription_id,
    "subscription_plan_id" => @plan_id_10k,
    "update_url" => "update_url.com",
    "cancel_url" => "cancel_url.com",
    "status" => "active",
    "next_bill_date" => "2019-06-01",
    "unit_price" => "6.00",
    "currency" => "EUR"
  }

  @subscription_updated_params %{
    "alert_name" => "subscription_updated",
    "passthrough" => "",
    "subscription_id" => "",
    "subscription_plan_id" => @plan_id_10k,
    "update_url" => "update_url.com",
    "cancel_url" => "cancel_url.com",
    "old_status" => "active",
    "status" => "active",
    "next_bill_date" => "2019-06-01",
    "new_unit_price" => "12.00",
    "currency" => "EUR"
  }

  describe "subscription_created" do
    test "creates a subscription" do
      user = insert(:user)

      %{@subscription_created_params | "passthrough" => user.id}
      |> Billing.subscription_created()

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.last_bill_date == ~D[2019-05-01]
      assert subscription.next_bill_amount == "6.00"
      assert subscription.currency_code == "EUR"
    end

    @tag :teams
    test "creates a subscription with teams passthrough" do
      user = insert(:user)
      {:ok, team} = Plausible.Teams.get_or_create(user)

      assert_team_exists(user)

      %{@subscription_created_params | "passthrough" => "user:#{user.id};team:#{team.id}"}
      |> Billing.subscription_created()

      assert Repo.get_by(Plausible.Billing.Subscription, user_id: user.id, team_id: team.id)
    end

    @tag :teams
    test "creates a team on create subscription" do
      user = insert(:user)

      %{@subscription_created_params | "passthrough" => user.id}
      |> Billing.subscription_created()

      team = assert_team_exists(user)
      assert Repo.get_by(Plausible.Billing.Subscription, user_id: user.id, team_id: team.id)
    end

    @tag :teams
    test "doesn't create additional teams on create subscription" do
      user = insert(:user)
      {:ok, team} = Plausible.Teams.get_or_create(user)

      %{@subscription_created_params | "passthrough" => user.id}
      |> Billing.subscription_created()

      team = assert_team_exists(user, team.id)
      assert Repo.get_by(Plausible.Billing.Subscription, user_id: user.id, team_id: team.id)
    end

    test "create with email address" do
      user = insert(:user)

      %{@subscription_created_params | "email" => user.email}
      |> Billing.subscription_created()

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.last_bill_date == ~D[2019-05-01]
      assert subscription.next_bill_amount == "6.00"
    end

    test "unlocks sites if user has any locked sites" do
      user = insert(:user)
      site = insert(:site, locked: true, members: [user])

      %{@subscription_created_params | "passthrough" => user.id}
      |> Billing.subscription_created()

      refute Repo.reload!(site).locked
    end

    @tag :ee_only
    test "updates accept_traffic_until" do
      user = insert(:user)

      %{@subscription_created_params | "passthrough" => user.id}
      |> Billing.subscription_created()

      next_bill = Date.from_iso8601!(@subscription_created_params["next_bill_date"])

      assert Repo.reload!(user).accept_traffic_until ==
               Date.add(next_bill, 30)
    end

    test "sets user.allow_next_upgrade_override field to false" do
      user = insert(:user, allow_next_upgrade_override: true)

      %{@subscription_created_params | "passthrough" => user.id}
      |> Billing.subscription_created()

      refute Repo.reload!(user).allow_next_upgrade_override
    end

    test "if user upgraded to an enterprise plan, their API key limits are automatically adjusted" do
      user = insert(:user)

      plan =
        insert(:enterprise_plan,
          user: user,
          paddle_plan_id: @plan_id_10k,
          hourly_api_request_limit: 10_000
        )

      api_key = insert(:api_key, user: user, hourly_request_limit: 1)

      %{@subscription_created_params | "passthrough" => user.id}
      |> Billing.subscription_created()

      assert Repo.reload!(api_key).hourly_request_limit == plan.hourly_api_request_limit
    end
  end

  describe "subscription_updated" do
    test "updates an existing subscription" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id
      })
      |> Billing.subscription_updated()

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_plan_id == @plan_id_10k
      assert subscription.next_bill_amount == "12.00"
    end

    @tag :teams
    test "creates a team on subscription update" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id
      })
      |> Billing.subscription_updated()

      team = assert_team_exists(user)
      assert Repo.get_by(Plausible.Billing.Subscription, user_id: user.id, team_id: team.id)
    end

    @tag :teams
    test "updates subscription with user/team passthrough" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)
      {:ok, team} = Plausible.Teams.get_or_create(user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => "user:#{user.id};team:#{team.id}"
      })
      |> Billing.subscription_updated()

      team = assert_team_exists(user)
      assert Repo.get_by(Plausible.Billing.Subscription, user_id: user.id, team_id: team.id)
    end

    @tag :teams
    test "syncs team properties with user on subscription update" do
      user =
        insert(:user, accept_traffic_until: ~D[2001-01-01], allow_next_upgrade_override: true)

      user = Plausible.Users.start_grace_period(user)

      subscription = insert(:subscription, user: user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id
      })
      |> Billing.subscription_updated()

      team = assert_team_exists(user)
      user = Repo.reload!(user)
      assert team.grace_period == user.grace_period
      assert team.trial_expiry_date == user.trial_expiry_date
      assert team.accept_traffic_until == user.accept_traffic_until
      assert team.allow_next_upgrade_override == user.allow_next_upgrade_override
    end

    test "status update from 'paused' to 'past_due' is ignored" do
      user = insert(:user)
      subscription = insert(:subscription, user: user, status: Subscription.Status.paused())

      %{@subscription_updated_params | "old_status" => "paused", "status" => "past_due"}
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id
      })
      |> Billing.subscription_updated()

      subscription = Repo.get_by(Subscription, user_id: user.id)
      assert subscription.status == Subscription.Status.paused()
    end

    test "unlocks sites if subscription is changed from past_due to active" do
      user = insert(:user)
      subscription = insert(:subscription, user: user, status: Subscription.Status.past_due())
      site = insert(:site, locked: true, members: [user])

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id,
        "old_status" => "past_due"
      })
      |> Billing.subscription_updated()

      refute Repo.reload!(site).locked
    end

    @tag :ee_only
    test "updates accept_traffic_until" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id
      })
      |> Billing.subscription_updated()

      next_bill = Date.from_iso8601!(@subscription_updated_params["next_bill_date"])

      assert Repo.reload!(user).accept_traffic_until ==
               Date.add(next_bill, 30)
    end

    test "sets user.allow_next_upgrade_override field to false" do
      user = insert(:user, allow_next_upgrade_override: true)
      subscription = insert(:subscription, user: user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id
      })
      |> Billing.subscription_updated()

      refute Repo.reload!(user).allow_next_upgrade_override
    end

    test "if user upgraded to an enterprise plan, their API key limits are automatically adjusted" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)

      plan =
        insert(:enterprise_plan,
          user: user,
          paddle_plan_id: "new-plan-id",
          hourly_api_request_limit: 10_000
        )

      api_key = insert(:api_key, user: user, hourly_request_limit: 1)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id,
        "subscription_plan_id" => plan.paddle_plan_id
      })
      |> Billing.subscription_updated()

      assert Repo.reload!(api_key).hourly_request_limit == plan.hourly_api_request_limit
    end

    test "if user's grace period has ended, upgrading will unlock sites and remove grace period" do
      grace_period = %Plausible.Auth.GracePeriod{end_date: Timex.shift(Timex.today(), days: -1)}
      user = insert(:user, grace_period: grace_period)

      subscription = insert(:subscription, user: user)
      site = insert(:site, locked: true, members: [user])

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription.paddle_subscription_id,
        "passthrough" => user.id,
        "subscription_plan_id" => @plan_id_100k
      })
      |> Billing.subscription_updated()

      assert Repo.reload!(site).locked == false
      assert Repo.reload!(user).grace_period == nil
    end

    test "ignores if subscription cannot be found" do
      user = insert(:user)

      res =
        @subscription_updated_params
        |> Map.merge(%{
          "subscription_id" => "666",
          "passthrough" => user.id
        })
        |> Billing.subscription_updated()

      assert {:ok, nil} = res
    end
  end

  describe "subscription_cancelled" do
    test "sets the status to deleted" do
      user = insert(:user)
      subscription = insert(:subscription, status: Subscription.Status.active(), user: user)

      Billing.subscription_cancelled(%{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => subscription.paddle_subscription_id,
        "status" => "deleted"
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert Subscription.Status.deleted?(subscription)
    end

    test "ignores if the subscription cannot be found" do
      res =
        Billing.subscription_cancelled(%{
          "alert_name" => "subscription_cancelled",
          "subscription_id" => "some_nonexistent_id",
          "status" => "deleted"
        })

      assert res == {:ok, nil}
    end

    test "sends an email to confirm cancellation" do
      user = insert(:user)
      subscription = insert(:subscription, status: Subscription.Status.active(), user: user)

      Billing.subscription_cancelled(%{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => subscription.paddle_subscription_id,
        "status" => "deleted"
      })

      assert_email_delivered_with(subject: "Mind sharing your thoughts on Plausible?")
    end
  end

  describe "subscription_payment_succeeded" do
    @tag :ee_only
    test "updates accept_traffic_until" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)

      refute user.accept_traffic_until

      Billing.subscription_payment_succeeded(%{
        "alert_name" => "subscription_payment_succeeded",
        "subscription_id" => subscription.paddle_subscription_id
      })

      user = Plausible.Users.with_subscription(user.id)
      assert user.accept_traffic_until == Date.add(user.subscription.next_bill_date, 30)
    end

    test "sets the next bill amount and date, last bill date" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)

      Billing.subscription_payment_succeeded(%{
        "alert_name" => "subscription_payment_succeeded",
        "subscription_id" => subscription.paddle_subscription_id
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.next_bill_date == ~D[2019-07-10]
      assert subscription.next_bill_amount == "6.00"
      assert subscription.last_bill_date == ~D[2019-06-10]
    end

    test "ignores if the subscription cannot be found" do
      res =
        Billing.subscription_payment_succeeded(%{
          "alert_name" => "subscription_payment_succeeded",
          "subscription_id" => "nonexistent_subscription_id",
          "next_bill_date" => Timex.shift(Timex.today(), days: 30),
          "unit_price" => "12.00"
        })

      assert res == {:ok, nil}
    end
  end

  describe "change_plan" do
    test "sets the next bill amount and date" do
      team = new_user() |> subscribe_to_growth_plan() |> team_of()

      Plausible.Teams.Billing.change_plan(team, "123123")

      subscription = Repo.get_by(Plausible.Billing.Subscription, team_id: team.id)
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
