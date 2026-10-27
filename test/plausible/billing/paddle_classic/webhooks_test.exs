defmodule Plausible.Billing.PaddleClassic.WebhooksTest do
  use Plausible.DataCase
  use Bamboo.Test, shared: true
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.PaddleClassic.Webhooks
  alias Plausible.Billing.Subscription
  alias Plausible.Repo

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
        |> Webhooks.subscription_created()
      end
    end

    test "fails on callback without valid passthrough" do
      _user = new_user()

      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        %{@subscription_created_params | "passthrough" => "invalid"}
        |> Webhooks.subscription_created()
      end

      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        %{@subscription_created_params | "passthrough" => "ee:true;user:invalid"}
        |> Webhooks.subscription_created()
      end

      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        %{@subscription_created_params | "passthrough" => "ee:true;user:123;team:invalid"}
        |> Webhooks.subscription_created()
      end

      assert_raise RuntimeError, ~r/Invalid passthrough sent via Paddle/, fn ->
        %{
          @subscription_created_params
          | "passthrough" => "ee:true;user:123;team:456;some:invalid"
        }
        |> Webhooks.subscription_created()
      end
    end

    test "fails on callback with non-existent user" do
      user = new_user()
      Repo.delete!(user)

      assert_raise Ecto.NoResultsError, fn ->
        %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id}"}
        |> Webhooks.subscription_created()
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
        |> Webhooks.subscription_created()
      end
    end

    test "creates a subscription with teams passthrough" do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Webhooks.subscription_created()

      subscription =
        user |> team_of() |> Plausible.Teams.with_subscription() |> Map.fetch!(:subscription)

      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.last_bill_date == ~D[2019-05-01]
      assert subscription.next_bill_amount == "6.00"
      assert subscription.currency_code == "EUR"
    end

    test "identical notification sent twice is ignored at 2nd try" do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)

      Plausible.Test.Support.Sentry.setup(self())

      Webhooks.subscription_created(%{
        @subscription_created_params
        | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })

      Webhooks.subscription_created(%{
        @subscription_created_params
        | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })

      subscription =
        user |> team_of() |> Plausible.Teams.with_subscription() |> Map.fetch!(:subscription)

      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.last_bill_date == ~D[2019-05-01]
      assert subscription.next_bill_amount == "6.00"
      assert subscription.currency_code == "EUR"

      assert [] = Sentry.Test.pop_sentry_reports()
    end

    test "secondary notification sent logs diff" do
      user = new_user()
      {:ok, team} = Plausible.Teams.get_or_create(user)

      Plausible.Test.Support.Sentry.setup(self())

      Webhooks.subscription_created(%{
        @subscription_created_params
        | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })

      Webhooks.subscription_created(%{
        @subscription_created_params
        | "subscription_plan_id" => "9999",
          "currency" => "USD",
          "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })

      assert [report] = Sentry.Test.pop_sentry_reports()

      assert report.message.formatted =~
               "Duplicate subscription_created webhook for paddle_subscription_id=subscription-123"

      assert report.extra.paddle_subscription_id == @subscription_id
      assert report.extra.team_id == team.id
      assert report.extra.diff.paddle_plan_id == %{existing: "654177", incoming: "9999"}
      assert report.extra.diff.currency_code == %{existing: "EUR", incoming: "USD"}

      subscription =
        user |> team_of() |> Plausible.Teams.with_subscription() |> Map.fetch!(:subscription)

      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.currency_code == "EUR"
    end

    test "supports user without a team case" do
      user = new_user()

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id}"}
      |> Webhooks.subscription_created()

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
      site = new_site(owner: user)
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      team = team_of(user)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Webhooks.subscription_created()

      refute Repo.reload!(team).locked
    end

    @tag :ee_only
    test "updates accept_traffic_until" do
      user = new_user()
      new_site(owner: user)
      team = team_of(user)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Webhooks.subscription_created()

      next_bill = Date.from_iso8601!(@subscription_created_params["next_bill_date"])

      assert Repo.reload!(team_of(user)).accept_traffic_until ==
               Date.add(next_bill, 30)
    end

    test "sets user.allow_next_upgrade_override field to false" do
      user = new_user(team: [allow_next_upgrade_override: true])
      team = team_of(user)

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Webhooks.subscription_created()

      refute Repo.reload!(team_of(user)).allow_next_upgrade_override
    end

    test "if user upgraded to an enterprise plan, their API key limits are automatically adjusted" do
      user = new_user()

      subscribe_to_enterprise_plan(user,
        hourly_api_request_limit: 10_000,
        paddle_plan_id: @plan_id_10k
      )

      team = team_of(user)

      _api_key = insert(:api_key, user: user)

      assert team.hourly_api_request_limit != 10_000

      %{@subscription_created_params | "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"}
      |> Webhooks.subscription_created()

      assert Repo.reload!(team).hourly_api_request_limit == 10_000
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
      |> Webhooks.subscription_updated()

      subscription = subscription_of(user)
      assert subscription.paddle_plan_id == @plan_id_10k
      assert subscription.next_bill_amount == "12.00"
    end

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
      |> Webhooks.subscription_updated()

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
      |> Webhooks.subscription_updated()

      assert subscription_of(user).status == Subscription.Status.paused()
    end

    test "unlocks sites if subscription is changed from past_due to active" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.past_due())
      site = new_site(owner: user)
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
      team = team_of(user)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
        "old_status" => "past_due"
      })
      |> Webhooks.subscription_updated()

      refute Repo.reload!(team).locked
    end

    test "cancels a pending team deletion schedule if subscription is changed from past_due to active" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.past_due())
      team = team_of(user)
      schedule = insert(:team_deletion_schedule, team: team, status: :first_notice_sent)

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
        "old_status" => "past_due"
      })
      |> Webhooks.subscription_updated()

      assert Repo.reload!(schedule).status == :cancelled
    end

    test "does not cancel a pending team deletion schedule if the update doesn't make the subscription active" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.past_due())
      team = team_of(user)
      schedule = insert(:team_deletion_schedule, team: team, status: :first_notice_sent)

      %{@subscription_updated_params | "old_status" => "past_due", "status" => "paused"}
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}"
      })
      |> Webhooks.subscription_updated()

      assert Repo.reload!(schedule).status == :first_notice_sent
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
      |> Webhooks.subscription_updated()

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
      |> Webhooks.subscription_updated()

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

      _api_key = insert(:api_key, user: user)

      assert team.hourly_api_request_limit != 10_000

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
        "subscription_plan_id" => "new-plan-id"
      })
      |> Webhooks.subscription_updated()

      assert Repo.reload!(team).hourly_api_request_limit == 10_000
    end

    test "if teams's grace period has ended, upgrading will unlock sites and remove grace period" do
      grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.shift(Date.utc_today(), day: -1)
      }

      user = new_user(team: [grace_period: grace_period])

      subscribe_to_growth_plan(user)

      team = team_of(user)

      site = new_site(owner: user)
      site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()

      subscription_id = subscription_of(user).paddle_subscription_id

      @subscription_updated_params
      |> Map.merge(%{
        "subscription_id" => subscription_id,
        "passthrough" => "ee:true;user:#{user.id};team:#{team.id}",
        "subscription_plan_id" => @plan_id_100k
      })
      |> Webhooks.subscription_updated()

      assert Repo.reload!(team).locked == false
      assert Repo.reload!(team).grace_period == nil
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
        |> Webhooks.subscription_updated()

      assert {:ok, nil} = res
    end
  end

  describe "subscription_cancelled" do
    test "sets the status to deleted" do
      user = new_user()
      subscribe_to_growth_plan(user, status: Subscription.Status.active())

      subscription_id = subscription_of(user).paddle_subscription_id

      Webhooks.subscription_cancelled(%{
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
        Webhooks.subscription_cancelled(%{
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

      Webhooks.subscription_cancelled(%{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => subscription_of(user).paddle_subscription_id,
        "status" => "deleted"
      })

      assert_email_delivered_with(
        to: [nil: user.email],
        subject: "Where did Plausible fall short?"
      )

      assert_email_delivered_with(
        to: [nil: billing_member.email],
        subject: "Where did Plausible fall short?"
      )
    end
  end

  describe "subscription_payment_succeeded" do
    @tag :ee_only
    test "updates accept_traffic_until" do
      user = new_user() |> subscribe_to_growth_plan()

      subscription_id = subscription_of(user).paddle_subscription_id

      Webhooks.subscription_payment_succeeded(%{
        "alert_name" => "subscription_payment_succeeded",
        "subscription_id" => subscription_id
      })

      team = user |> team_of() |> Repo.reload!() |> Plausible.Teams.with_subscription()
      assert team.accept_traffic_until == Date.add(team.subscription.next_bill_date, 30)
    end

    test "sets the next bill amount and date, last bill date" do
      user = new_user() |> subscribe_to_growth_plan()

      Webhooks.subscription_payment_succeeded(%{
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
        Webhooks.subscription_payment_succeeded(%{
          "alert_name" => "subscription_payment_succeeded",
          "subscription_id" => "nonexistent_subscription_id",
          "next_bill_date" => Date.shift(Date.utc_today(), day: 30),
          "unit_price" => "12.00"
        })

      assert res == {:ok, nil}
    end

    test "cancels a pending team deletion schedule" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)
      schedule = insert(:team_deletion_schedule, team: team, status: :first_notice_sent)

      Webhooks.subscription_payment_succeeded(%{
        "alert_name" => "subscription_payment_succeeded",
        "subscription_id" => subscription_of(user).paddle_subscription_id
      })

      assert Repo.reload!(schedule).status == :cancelled
    end
  end
end
