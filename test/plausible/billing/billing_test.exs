defmodule Plausible.BillingTest do
  use Plausible.DataCase
  alias Plausible.Billing

  describe "trial_days_left" do
    test "is 30 days for new signup" do
      user = insert(:user)

      assert Billing.trial_days_left(user) == 30
    end

    test "is 29 days for day old user" do
      user = insert(:user, inserted_at: Timex.shift(Timex.now(), days: -1))

      assert Billing.trial_days_left(user) == 29
    end
  end

  @subscription_id "subscription-123"
  @plan_id "plan-123"


  describe "subscription_created" do
    test "creates a subscription" do
      user = insert(:user)
      Billing.subscription_created(%{
        "alert_name" => "subscription_created",
        "subscription_id" => @subscription_id,
        "subscription_plan_id" => @plan_id,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "unit_price" => "6.00"
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.next_bill_amount == "6.00"
    end

    test "create with email address" do
      user = insert(:user)

      Billing.subscription_created(%{
        "email" => user.email,
        "alert_name" => "subscription_created",
        "subscription_id" => @subscription_id,
        "subscription_plan_id" => @plan_id,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "unit_price" => "6.00"
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.next_bill_amount == "6.00"
    end
  end

  describe "subscription_updated" do
    test "updates an existing subscription" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)

      Billing.subscription_updated(%{
        "alert_name" => "subscription_updated",
        "subscription_id" => subscription.paddle_subscription_id,
        "subscription_plan_id" => "new-plan-id",
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "new_unit_price" => "12.00"
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_plan_id == "new-plan-id"
      assert subscription.next_bill_amount == "12.00"
    end
  end

  describe "subscription_cancelled" do
    test "sets the status to deleted" do
      user = insert(:user)
      subscription = insert(:subscription, status: "active", user: user)

      Billing.subscription_cancelled(%{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => subscription.paddle_subscription_id,
        "status" => "deleted"
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.status == "deleted"
    end

    test "ignores if the subscription cannot be found" do
      res = Billing.subscription_cancelled(%{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => "some_nonexistent_id",
        "status" => "deleted"
      })

      assert res == {:ok, nil}
    end
  end

  describe "subscription_payment_succeeded" do
    test "sets the next bill amount and date" do
      user = insert(:user)
      subscription = insert(:subscription, user: user)

      Billing.subscription_payment_succeeded(%{
        "alert_name" => "subscription_payment_succeeded",
        "subscription_id" => subscription.paddle_subscription_id
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.next_bill_date == ~D[2019-07-10]
      assert subscription.next_bill_amount == "6.00"
    end

    test "ignores if the subscription cannot be found" do
      res = Billing.subscription_payment_succeeded(%{
        "alert_name" => "subscription_payment_succeeded",
        "subscription_id" => "nonexistent_subscription_id",
        "next_bill_date" => Timex.shift(Timex.today(), days: 30),
        "unit_price" => "12.00"
      })

      assert res == {:ok, nil}
    end
  end
end
