defmodule Plausible.BillingTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  use Bamboo.Test, shared: true
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing
  alias Plausible.Billing.Subscription

  describe "check_needs_to_upgrade" do
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
    test "fails on callback without passthrough" do
      _user = new_user()

      assert_raise RuntimeError, ~r/Missing passthrough/, fn ->
        @subscription_created_params
        |> Map.delete("passthrough")
        |> Billing.subscription_created()
      end
    end

    test "fails on callback without valid passthrough" do
      _user = new_user()

      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        %{@subscription_created_params | "passthrough" => "invalid"}
        |> Billing.subscription_created()
      end

      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        %{@subscription_created_params | "passthrough" => "ee:true;user:invalid"}
        |> Billing.subscription_created()
      end

      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        %{@subscription_created_params | "passthrough" => "ee:true;user:123;team:invalid"}
        |> Billing.subscription_created()
      end

      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        %{
          @subscription_created_params
          | "passthrough" => "ee:true;user:123;team:456;some:invalid"
        }
        |> Billing.subscription_created()
      end
    end

    test "fails on callback with non-existent user" do
      user = new_user()
      Repo.delete!(user)

      assert_raise Ecto.NoResultsError, fn ->
        %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id}"}
        |> Billing.subscription_created()
      end
    end

    test "fails on callback with non-existent team" do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)
      Repo.delete!(team)

      assert_raise Ecto.NoResultsError, fn ->
        %{
          @subscription_created_params
          | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
        }
        |> Billing.subscription_created()
      end
    end

    test "creates a subscription with teams passthrough" do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Billing.subscription_created()

      subscription =
        user |> team_of() |> Plausible.Teams.with_subscription() |> Map.fetch!(:subscription)

      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.last_bill_date == ~D[2019-05-01]
      assert subscription.next_bill_amount == "6.00"
      assert subscription.currency_code == "EUR"
    end

    test "supports user without a team case" do
      user = new_user()

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id}"}
      |> Billing.subscription_created()

      subscription =
        user |> team_of() |> Plausible.Teams.with_subscription() |> Map.fetch!(:subscription)

      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.last_bill_date == ~D[2019-05-01]
      assert subscription.next_bill_amount == "6.00"
      assert subscription.currency_code == "EUR"
    end

    test "unlocks sites if user has any locked sites" do
      user = new_user()
      site = new_site(owner: user, locked: true)
      team = team_of(user)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Billing.subscription_created()

      refute Repo.reload!(site).locked
    end

    @tag :ee_only
    test "updates accept_traffic_until" do
      user = new_user()
      new_site(owner: user)
      team = team_of(user)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Billing.subscription_created()

      next_bill = Date.from_iso8601!(@subscription_created_params["next_bill_date"])

      assert Repo.reload!(team_of(user)).accept_traffic_until ==
               Date.add(next_bill, 30)
    end

    test "sets user.allow_next_upgrade_override field to false" do
      user = new_user(team: [allow_next_upgrade_override: true])
      team = team_of(user)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Billing.subscription_created()

      refute Repo.reload!(team_of(user)).allow_next_upgrade_override
    end

    test "if user upgraded to an enterprise plan, their API key limits are automatically adjusted" do
      user = new_user()

      subscribe_to_enterprise_plan(user,
        hourly_api_request_limit: 10_000,
        paddle_plan_id: @plan_id_10k
      )

      team = team_of(user)

      api_key = insert(:api_key, user: user, hourly_request_limit: 1)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Billing.subscription_created()

      assert Repo.reload!(api_key).hourly_request_limit == 10_000
    end
  end

  describe "subscription_updated" do
    test "updates an existing subscription" do
      user = new_user()
      subscribe_to_growth_plan(user)
      team = team_of(user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })
      |> Billing.subscription_updated()

      subscription = subscription_of(user)
      assert subscription.paddle_plan_id == @plan_id_10k
      assert subscription.next_bill_amount == "12.00"
    end

    @tag :teams
    test "updates subscription with user/team passthrough" do
      user = new_user()
      subscribe_to_growth_plan(user)
      team = team_of(user)

      subscription_id = subscription_of(user).paddle_subscription_id

      @subscription_updated_params
      |> Map.merge(%{
        "next_bill_date" => "2021-01-01",
        "subscription_id" => subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })
      |> Billing.subscription_updated()

      subscription =
        user |> team_of() |> Plausible.Teams.with_subscription() |> Map.fetch!(:subscription)

      assert subscription.next_bill_date == ~D[2021-01-01]
    end

    test "status update from 'paused' to 'past_due' is ignored" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.paused())
      team = team_of(user)

      %{@subscription_updated_params | "old_status" => "paused", "status" => "past_due"}
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })
      |> Billing.subscription_updated()

      assert subscription_of(user).status == Subscription.Status.paused()
    end

    test "unlocks sites if subscription is changed from past_due to active" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.past_due())
      site = new_site(locked: true, owner: user)
      team = team_of(user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
        "old_status" => "past_due"
      })
      |> Billing.subscription_updated()

      refute Repo.reload!(site).locked
    end

    @tag :ee_only
    test "updates accept_traffic_until" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })
      |> Billing.subscription_updated()

      next_bill = Date.from_iso8601!(@subscription_updated_params["next_bill_date"])

      assert Repo.reload!(team_of(user)).accept_traffic_until ==
               Date.add(next_bill, 30)
    end

    test "sets user.allow_next_upgrade_override field to false" do
      user = new_user(team: [allow_next_upgrade_override: true])
      subscribe_to_growth_plan(user)
      team = team_of(user)

      assert Repo.reload!(team_of(user)).allow_next_upgrade_override

      subscription_id = subscription_of(user).paddle_subscription_id

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })
      |> Billing.subscription_updated()

      refute Repo.reload!(team_of(user)).allow_next_upgrade_override
    end

    test "if user upgraded to an enterprise plan, their API key limits are automatically adjusted" do
      user =
        new_user()
        |> subscribe_to_enterprise_plan(
          paddle_plan_id: "new-plan-id",
          hourly_api_request_limit: 10_000
        )

      team = team_of(user)

      api_key = insert(:api_key, user: user, hourly_request_limit: 1)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
        "subscription_plan_id" => "new-plan-id"
      })
      |> Billing.subscription_updated()

      assert Repo.reload!(api_key).hourly_request_limit == 10_000
    end

    test "if teams's grace period has ended, upgrading will unlock sites and remove grace period" do
      grace_period = %Plausible.Teams.GracePeriod{end_date: Timex.shift(Timex.today(), days: -1)}
      user = new_user(team: [grace_period: grace_period])

      subscribe_to_growth_plan(user)

      team = team_of(user)

      site = new_site(locked: true, owner: user)

      subscription_id = subscription_of(user).paddle_subscription_id

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
        "subscription_plan_id" => @plan_id_100k
      })
      |> Billing.subscription_updated()

      assert Repo.reload!(site).locked == false
      assert Repo.reload!(team_of(user)).grace_period == nil
    end

    test "ignores if subscription cannot be found" do
      user = insert(:user)
      _site = new_site(owner: user)
      team = team_of(user)

      res =
        @subscription_updated_params
        |> Map.merge(%{
          "subscription_id" => "666",
          "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
        })
        |> Billing.subscription_updated()

      assert {:ok, nil} = res
    end
  end

  describe "subscription_cancelled" do
    test "sets the status to deleted" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.active())

      subscription_id = subscription_of(user).paddle_subscription_id

      Billing.subscription_cancelled(%{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => subscription_id,
        "status" => "deleted"
      })

      assert user
             |> team_of()
             |> Repo.reload!()
             |> Plausible.Teams.with_subscription()
             |> Map.fetch!(:subscription)
             |> Subscription.Status.deleted?()
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
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.active())

      team = team_of(user)
      billing_member = new_user()
      add_member(team, user: billing_member, role: :billing)

      Billing.subscription_cancelled(%{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "status" => "deleted"
      })

      assert_email_delivered_with(
        to: [nil: user.email],
        subject: "Mind sharing your thoughts on Plausible?"
      )

      assert_email_delivered_with(
        to: [nil: billing_member.email],
        subject: "Mind sharing your thoughts on Plausible?"
      )
    end
  end

  describe "subscription_payment_succeeded" do
    @tag :ee_only
    test "updates accept_traffic_until" do
      user = new_user() |> subscribe_to_growth_plan()

      subscription_id = subscription_of(user).paddle_subscription_id

      Billing.subscription_payment_succeeded(%{
        "alert_name" => "subscription_payment_succeeded",
        "subscription_id" => subscription_id
      })

      team = user |> team_of() |> Repo.reload!() |> Plausible.Teams.with_subscription()
      assert team.accept_traffic_until == Date.add(team.subscription.next_bill_date, 30)
    end

    test "sets the next bill amount and date, last bill date" do
      user = new_user() |> subscribe_to_growth_plan()

      Billing.subscription_payment_succeeded(%{
        "alert_name" => "subscription_payment_succeeded",
        "subscription_id" => subscription_of(user).paddle_subscription_id
      })

      subscription = subscription_of(user)
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

  def monthly_pageview_usage_stub(penultimate_usage, last_usage) do
    last_bill_date = Date.utc_today() |> Date.shift(day: -1)

    Plausible.Teams.Billing
    |> Double.stub(:monthly_pageview_usage, fn _user ->
      %{
        last_cycle: %{
          date_range:
            Date.range(
              Date.shift(last_bill_date, month: -1),
              Date.shift(last_bill_date, day: -1)
            ),
          total: last_usage
        },
        penultimate_cycle: %{
          date_range:
            Date.range(
              Date.shift(last_bill_date, month: -2),
              Date.shift(last_bill_date, day: -1, month: -1)
            ),
          total: penultimate_usage
        }
      }
    end)
  end
end
