defmodule Plausible.BillingTest do
  use Plausible.DataCase
  use Bamboo.Test, shared: true
  alias Plausible.Billing

  describe "usage" do
    test "is 0 with no events" do
      user = insert(:user)

      assert Billing.usage(user) == 0
    end

    test "counts the total number of events from all sites the user owns" do
      user = insert(:user)
      site1 = insert(:site, members: [user])
      site2 = insert(:site, members: [user])

      populate_stats(site1, [
        build(:pageview),
        build(:pageview)
      ])

      populate_stats(site2, [
        build(:pageview),
        build(:event, name: "custom events")
      ])

      assert Billing.usage(user) == 4
    end

    test "only counts usage from sites where the user is the owner" do
      user = insert(:user)

      insert(:site,
        domain: "site-with-no-views.com",
        memberships: [
          build(:site_membership, user: user, role: :owner)
        ]
      )

      insert(:site,
        domain: "test-site.com",
        memberships: [
          build(:site_membership, user: user, role: :admin)
        ]
      )

      assert Billing.usage(user) == 0
    end
  end

  describe "last_two_billing_cycles" do
    test "billing on the 1st" do
      last_bill_date = ~D[2021-01-01]
      today = ~D[2021-01-02]

      user = insert(:user, subscription: build(:subscription, last_bill_date: last_bill_date))

      expected_cycles = {
        Date.range(~D[2020-11-01], ~D[2020-11-30]),
        Date.range(~D[2020-12-01], ~D[2020-12-31])
      }

      assert Billing.last_two_billing_cycles(user, today) == expected_cycles
    end

    test "in case of yearly billing, cycles are normalized as if they were paying monthly" do
      last_bill_date = ~D[2020-09-01]
      today = ~D[2021-02-02]

      user = insert(:user, subscription: build(:subscription, last_bill_date: last_bill_date))

      expected_cycles = {
        Date.range(~D[2020-12-01], ~D[2020-12-31]),
        Date.range(~D[2021-01-01], ~D[2021-01-31])
      }

      assert Billing.last_two_billing_cycles(user, today) == expected_cycles
    end
  end

  describe "last_two_billing_months_usage" do
    test "counts events from last two billing cycles" do
      last_bill_date = ~D[2021-01-01]
      today = ~D[2021-01-02]
      user = insert(:user, subscription: build(:subscription, last_bill_date: last_bill_date))
      site = insert(:site, members: [user])

      create_pageviews([
        %{site: site, timestamp: ~N[2021-01-01 00:00:00]},
        %{site: site, timestamp: ~N[2020-12-31 00:00:00]},
        %{site: site, timestamp: ~N[2020-11-01 00:00:00]},
        %{site: site, timestamp: ~N[2020-10-31 00:00:00]}
      ])

      assert Billing.last_two_billing_months_usage(user, today) == {1, 1}
    end

    test "only considers sites that the user owns" do
      last_bill_date = ~D[2021-01-01]
      today = ~D[2021-01-02]

      user = insert(:user, subscription: build(:subscription, last_bill_date: last_bill_date))

      owner_site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :owner)
          ]
        )

      admin_site =
        insert(:site,
          memberships: [
            build(:site_membership, user: user, role: :admin)
          ]
        )

      create_pageviews([
        %{site: owner_site, timestamp: ~N[2020-12-31 00:00:00]},
        %{site: admin_site, timestamp: ~N[2020-12-31 00:00:00]},
        %{site: owner_site, timestamp: ~N[2020-11-01 00:00:00]},
        %{site: admin_site, timestamp: ~N[2020-11-01 00:00:00]}
      ])

      assert Billing.last_two_billing_months_usage(user, today) == {1, 1}
    end

    test "gets event count from last month and this one" do
      user =
        insert(:user,
          subscription:
            build(:subscription, last_bill_date: Timex.today() |> Timex.shift(days: -1))
        )

      assert Billing.last_two_billing_months_usage(user) == {0, 0}
    end
  end

  describe "trial_days_left" do
    test "is 30 days for new signup" do
      user = insert(:user)

      assert Billing.trial_days_left(user) == 30
    end

    test "is based on trial_expiry_date" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.now(), days: 1))

      assert Billing.trial_days_left(user) == 1
    end
  end

  describe "on_trial?" do
    test "is true with >= 0 trial days left" do
      user = insert(:user)

      assert Billing.on_trial?(user)
    end

    test "is false with < 0 trial days left" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.now(), days: -1))

      refute Billing.on_trial?(user)
    end

    test "is false if user has subscription" do
      user = insert(:user, subscription: build(:subscription))

      refute Billing.on_trial?(user)
    end
  end

  describe "needs_to_upgrade?" do
    test "is false for a trial user" do
      user = insert(:user)
      refute Billing.needs_to_upgrade?(user)
    end

    test "is true for a user with an expired trial" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))

      assert Billing.needs_to_upgrade?(user)
    end

    test "is false for a user with an expired trial but an active subscription" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))
      insert(:subscription, user: user)

      refute Billing.needs_to_upgrade?(user)
    end

    test "is false for a user with a cancelled subscription IF the billing cycle isn't completed yet" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))
      insert(:subscription, user: user, status: "deleted", next_bill_date: Timex.today())

      refute Billing.needs_to_upgrade?(user)
    end

    test "is true for a user with a cancelled subscription IF the billing cycle is complete" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))

      insert(:subscription,
        user: user,
        status: "deleted",
        next_bill_date: Timex.shift(Timex.today(), days: -1)
      )

      assert Billing.needs_to_upgrade?(user)
    end

    test "is false for a deleted subscription if not next_bill_date specified" do
      user = insert(:user, trial_expiry_date: Timex.shift(Timex.today(), days: -1))
      insert(:subscription, user: user, status: "deleted", next_bill_date: nil)

      assert Billing.needs_to_upgrade?(user)
    end
  end

  @subscription_id "subscription-123"
  @plan_id_10k "654177"
  @plan_id_100k "654178"

  describe "subscription_created" do
    test "creates a subscription" do
      user = insert(:user)

      Billing.subscription_created(%{
        "alert_name" => "subscription_created",
        "subscription_id" => @subscription_id,
        "subscription_plan_id" => @plan_id_10k,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "unit_price" => "6.00",
        "currency" => "EUR"
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.next_bill_amount == "6.00"
      assert subscription.currency_code == "EUR"
    end

    test "create with email address" do
      user = insert(:user)

      Billing.subscription_created(%{
        "passthrough" => "",
        "email" => user.email,
        "alert_name" => "subscription_created",
        "subscription_id" => @subscription_id,
        "subscription_plan_id" => @plan_id_10k,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "unit_price" => "6.00",
        "currency" => "EUR"
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_subscription_id == @subscription_id
      assert subscription.next_bill_date == ~D[2019-06-01]
      assert subscription.next_bill_amount == "6.00"
    end

    test "unlocks sites if user has any locked sites" do
      user = insert(:user)
      site = insert(:site, locked: true, members: [user])

      Billing.subscription_created(%{
        "alert_name" => "subscription_created",
        "subscription_id" => @subscription_id,
        "subscription_plan_id" => @plan_id_10k,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "unit_price" => "6.00",
        "currency" => "EUR"
      })

      refute Repo.reload!(site).locked
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

      Billing.subscription_created(%{
        "alert_name" => "subscription_created",
        "subscription_id" => @subscription_id,
        "subscription_plan_id" => @plan_id_10k,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "unit_price" => "6.00",
        "currency" => "EUR"
      })

      assert Repo.reload!(api_key).hourly_request_limit == plan.hourly_api_request_limit
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
        "new_unit_price" => "12.00",
        "currency" => "EUR"
      })

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_plan_id == "new-plan-id"
      assert subscription.next_bill_amount == "12.00"
    end

    test "unlocks sites if subscription is changed from past_due to active" do
      user = insert(:user)
      subscription = insert(:subscription, user: user, status: "past_due")
      site = insert(:site, locked: true, members: [user])

      Billing.subscription_updated(%{
        "alert_name" => "subscription_updated",
        "subscription_id" => subscription.paddle_subscription_id,
        "subscription_plan_id" => "new-plan-id",
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "old_status" => "past_due",
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "new_unit_price" => "12.00",
        "currency" => "EUR"
      })

      refute Repo.reload!(site).locked
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

      Billing.subscription_updated(%{
        "alert_name" => "subscription_updated",
        "subscription_id" => subscription.paddle_subscription_id,
        "subscription_plan_id" => "new-plan-id",
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "old_status" => "past_due",
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "new_unit_price" => "12.00",
        "currency" => "EUR"
      })

      assert Repo.reload!(api_key).hourly_request_limit == plan.hourly_api_request_limit
    end

    test "if user's grace period has ended, upgrading to the proper plan will unlock sites and remove grace period" do
      user =
        insert(:user,
          grace_period: %Plausible.Auth.GracePeriod{
            end_date: Timex.shift(Timex.today(), days: -1),
            allowance_required: 11_000
          }
        )

      subscription = insert(:subscription, user: user)
      site = insert(:site, locked: true, members: [user])

      Billing.subscription_updated(%{
        "alert_name" => "subscription_updated",
        "subscription_id" => subscription.paddle_subscription_id,
        "subscription_plan_id" => @plan_id_100k,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "old_status" => "past_due",
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "new_unit_price" => "12.00",
        "currency" => "EUR"
      })

      assert Repo.reload!(site).locked == false
      assert Repo.reload!(user).grace_period == nil
    end

    test "does not remove grace period if upgraded plan allowance is too low" do
      user =
        insert(:user,
          grace_period: %Plausible.Auth.GracePeriod{
            end_date: Timex.shift(Timex.today(), days: -1),
            allowance_required: 11_000
          }
        )

      subscription = insert(:subscription, user: user)
      site = insert(:site, locked: true, members: [user])

      Billing.subscription_updated(%{
        "alert_name" => "subscription_updated",
        "subscription_id" => subscription.paddle_subscription_id,
        "subscription_plan_id" => @plan_id_10k,
        "update_url" => "update_url.com",
        "cancel_url" => "cancel_url.com",
        "passthrough" => user.id,
        "old_status" => "past_due",
        "status" => "active",
        "next_bill_date" => "2019-06-01",
        "new_unit_price" => "12.00",
        "currency" => "EUR"
      })

      assert Repo.reload!(site).locked == true
      assert Repo.reload!(user).grace_period.allowance_required == 11_000
    end

    test "ignores if subscription cannot be found" do
      user = insert(:user)

      res =
        Billing.subscription_updated(%{
          "alert_name" => "subscription_updated",
          "subscription_id" => "666",
          "subscription_plan_id" => "new-plan-id",
          "update_url" => "update_url.com",
          "cancel_url" => "cancel_url.com",
          "passthrough" => user.id,
          "status" => "active",
          "next_bill_date" => "2019-06-01",
          "new_unit_price" => "12.00",
          "currency" => "EUR"
        })

      assert res == {:ok, nil}
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
      subscription = insert(:subscription, status: "active", user: user)

      Billing.subscription_cancelled(%{
        "alert_name" => "subscription_cancelled",
        "subscription_id" => subscription.paddle_subscription_id,
        "status" => "deleted"
      })

      assert_email_delivered_with(
        subject: "Your Plausible Analytics subscription has been canceled"
      )
    end
  end

  describe "subscription_payment_succeeded" do
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
      user = insert(:user)
      insert(:subscription, user: user)

      Billing.change_plan(user, "123123")

      subscription = Repo.get_by(Plausible.Billing.Subscription, user_id: user.id)
      assert subscription.paddle_plan_id == "123123"
      assert subscription.next_bill_date == ~D[2019-07-10]
      assert subscription.next_bill_amount == "6.00"
    end
  end

  test "active_subscription_for/1 returns active subscription" do
    active = insert(:subscription, user: insert(:user), status: "active")
    paused = insert(:subscription, user: insert(:user), status: "paused")
    user_without_subscription = insert(:user)

    assert Billing.active_subscription_for(active.user_id).id == active.id
    assert Billing.active_subscription_for(paused.user_id) == nil
    assert Billing.active_subscription_for(user_without_subscription.id) == nil
  end

  test "has_active_subscription?/1 returns whether the user has an active subscription" do
    active = insert(:subscription, user: insert(:user), status: "active")
    paused = insert(:subscription, user: insert(:user), status: "paused")
    user_without_subscription = insert(:user)

    assert Billing.has_active_subscription?(active.user_id)
    refute Billing.has_active_subscription?(paused.user_id)
    refute Billing.has_active_subscription?(user_without_subscription.id)
  end
end
