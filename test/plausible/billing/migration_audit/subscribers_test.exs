defmodule Plausible.Billing.MigrationAudit.SubscribersTest do
  use Plausible.DataCase, async: true

  alias Plausible.Billing.MigrationAudit.Subscribers
  alias Plausible.Billing.{Plans, Subscription}

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription.Status

  @today ~D[2026-10-20]

  # a plan with both a monthly and a yearly id
  defp plan(), do: Enum.find(Plans.all(), &(&1.monthly_product_id && &1.yearly_product_id))

  describe "statuses" do
    test "counts the current subscription of every team by status" do
      plan_id = plan().monthly_product_id
      yesterday = Date.shift(@today, day: -1)

      new_user() |> subscribe_to_plan(plan_id)
      new_user() |> subscribe_to_plan(plan_id)
      new_user() |> subscribe_to_plan(plan_id, status: Status.past_due())
      new_user() |> subscribe_to_plan(plan_id, status: Status.paused())
      new_user() |> subscribe_to_plan(plan_id, status: Status.deleted(), next_bill_date: @today)

      new_user()
      |> subscribe_to_plan(plan_id, status: Status.deleted(), next_bill_date: yesterday)

      new_user() |> subscribe_to_plan("free_10k")
      new_user() |> subscribe_to_plan(Subscription.manual_plan_id())

      assert %{teams_with_subscription: 8, by_status: by_status} =
               Subscribers.audit(today: @today, list_prices: %{}).statuses

      assert Map.new(by_status, &{&1.status, &1.teams}) == %{
               "active" => 2,
               "past_due" => 1,
               "paused" => 1,
               "cancelled_paid_up" => 1,
               "cancelled_expired" => 1,
               "free_10k" => 1,
               "manual" => 1
             }
    end

    test "only the last subscription of a team counts" do
      plan_id = plan().monthly_product_id
      team = new_user() |> subscribe_to_plan(plan_id, status: Status.deleted()) |> team_of()
      insert(:subscription, team: team, paddle_plan_id: plan_id)

      assert %{by_status: [%{status: "active", teams: 1}]} =
               Subscribers.audit(today: @today, list_prices: %{}).statuses
    end

    test "counts teams in the app's own trial that never subscribed" do
      plan_id = plan().monthly_product_id

      # the test database can hold teams of its own, so compare against a baseline
      baseline = Subscribers.audit(today: @today, list_prices: %{}).statuses.teams_on_app_trial

      new_user(trial_expiry_date: Date.shift(@today, day: 5))
      new_user(trial_expiry_date: Date.shift(@today, day: -5))

      new_user(trial_expiry_date: Date.shift(@today, day: 5))
      |> subscribe_to_plan(plan_id)

      assert Subscribers.audit(today: @today, list_prices: %{}).statuses.teams_on_app_trial ==
               baseline + 1
    end
  end

  describe "billed" do
    test "groups live paid subscriptions by kind, currency and interval" do
      plan = plan()

      new_user() |> subscribe_to_plan(plan.monthly_product_id, next_bill_amount: "6.00")
      new_user() |> subscribe_to_plan(plan.monthly_product_id, next_bill_amount: "10.50")

      new_user()
      |> subscribe_to_plan(plan.yearly_product_id,
        next_bill_amount: "60.00",
        currency_code: "EUR"
      )

      new_user() |> subscribe_to_enterprise_plan(billing_interval: :yearly)

      new_user()
      |> subscribe_to_plan(plan.monthly_product_id, next_bill_amount: "oops")

      # not live, free and manual ones are left out
      new_user()
      |> subscribe_to_plan(plan.monthly_product_id,
        status: Status.deleted(),
        next_bill_date: Date.shift(@today, day: -1)
      )

      new_user() |> subscribe_to_plan("free_10k")
      new_user() |> subscribe_to_plan(Subscription.manual_plan_id())

      billed = Subscribers.audit(today: @today, list_prices: %{}).billed

      assert [
               %{
                 kind: :regular,
                 currency: "USD",
                 interval: :monthly,
                 subscriptions: 3,
                 unparsable_amounts: 1,
                 total: "16.50",
                 min: "6.00",
                 max: "10.50"
               }
             ] = Enum.filter(billed, &(&1.interval == :monthly and &1.kind == :regular))

      assert Enum.any?(billed, &match?(%{kind: :regular, currency: "EUR", interval: :yearly}, &1))
      assert Enum.any?(billed, &match?(%{kind: :enterprise, interval: :yearly}, &1))
      assert Enum.sum(Enum.map(billed, & &1.subscriptions)) == 5
    end

    test "an unknown plan id is reported as unresolved" do
      new_user() |> subscribe_to_plan("no-such-plan")

      assert [%{kind: :unresolved, interval: :unknown, subscriptions: 1}] =
               Subscribers.audit(today: @today, list_prices: %{}).billed
    end
  end

  describe "vs_list_price" do
    test "compares what is paid to the USD list price" do
      id = plan().monthly_product_id

      new_user() |> subscribe_to_plan(id, next_bill_amount: "10.00")
      new_user() |> subscribe_to_plan(id, next_bill_amount: "10.00", currency_code: "EUR")
      new_user() |> subscribe_to_plan(id, next_bill_amount: "8.00")
      new_user() |> subscribe_to_plan(id, next_bill_amount: "8.00")
      new_user() |> subscribe_to_plan(id, next_bill_amount: "12.00")
      new_user() |> subscribe_to_plan(id, next_bill_amount: "x")
      new_user() |> subscribe_to_enterprise_plan()

      result = Subscribers.audit(today: @today, list_prices: %{id => 10}).vs_list_price

      assert [usd, eur] = result.by_currency

      assert %{currency: "USD", subscriptions: 5, equal: 1, lower: 2, higher: 1, unparsable: 1} =
               usd

      assert %{currency: "EUR", subscriptions: 1, equal: 1, lower: 0, higher: 0} = eur

      assert [
               %{paid: "8.00", list_price: "10.00", comparison: :lower, subscriptions: 2},
               %{paid: "12.00", comparison: :higher, subscriptions: 1}
             ] = result.off_list_price_points
    end

    test "plans without a list price are counted separately" do
      new_user() |> subscribe_to_plan(plan().monthly_product_id)

      assert [%{no_list_price: 1, equal: 0}] =
               Subscribers.audit(today: @today, list_prices: %{}).vs_list_price.by_currency
    end
  end

  describe "enterprise" do
    test "summarises price points of live enterprise plans" do
      new_user() |> subscribe_to_enterprise_plan(subscription: [next_bill_amount: "100.00"])
      new_user() |> subscribe_to_enterprise_plan(subscription: [next_bill_amount: "100.00"])
      new_user() |> subscribe_to_enterprise_plan(subscription: [next_bill_amount: "250.00"])

      new_user()
      |> subscribe_to_enterprise_plan(
        billing_interval: :yearly,
        subscription: [next_bill_amount: "900.00"]
      )

      # not live
      new_user()
      |> subscribe_to_enterprise_plan(
        subscription: [status: Status.deleted(), next_bill_date: Date.shift(@today, day: -1)]
      )

      enterprise = Subscribers.audit(today: @today, list_prices: %{}).enterprise

      assert %{live_subscriptions: 4, distinct_plan_ids: 4, distinct_price_points: 3} = enterprise

      assert [%{interval: :monthly, subscriptions: 3}, %{interval: :yearly, subscriptions: 1}] =
               enterprise.by_interval

      assert [
               %{amount: "100.00", interval: :monthly, subscriptions: 2},
               %{subscriptions: 1},
               %{subscriptions: 1}
             ] = enterprise.top_price_points
    end

    test "reports plan ids shared by several teams and teams with several plans" do
      shared = "shared-plan"
      new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: shared)
      new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: shared)

      user = new_user() |> subscribe_to_enterprise_plan()
      team = team_of(user)
      insert(:enterprise_plan, team: team, paddle_plan_id: "another")
      insert(:subscription, team: team, paddle_plan_id: "another")

      enterprise = Subscribers.audit(today: @today, list_prices: %{}).enterprise

      assert enterprise.plan_ids_shared_by_several_teams == 1
      assert enterprise.teams_with_several_enterprise_plans == 1
    end

    test "enterprise plans without a matching subscription are not counted" do
      shared = "shared-plan"
      new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: shared)

      # same plan id, but this team has no subscription for it
      other = new_user()
      {:ok, other_team} = Plausible.Teams.get_or_create(other)
      insert(:enterprise_plan, team: other_team, paddle_plan_id: shared)

      user = new_user() |> subscribe_to_enterprise_plan()
      insert(:enterprise_plan, team: team_of(user), paddle_plan_id: "not-subscribed-yet")

      enterprise = Subscribers.audit(today: @today, list_prices: %{}).enterprise

      assert enterprise.plan_ids_shared_by_several_teams == 0
      assert enterprise.teams_with_several_enterprise_plans == 0
    end
  end

  test "an empty database gives an empty audit" do
    result = Subscribers.audit(today: @today, list_prices: %{})

    assert result.billed == []
    assert %{teams_with_subscription: 0, by_status: []} = result.statuses
    assert result.enterprise.live_subscriptions == 0
    assert result.vs_list_price == %{by_currency: [], off_list_price_points: []}
  end

  test "reads the list prices from the priv directory by default" do
    id = plan().monthly_product_id
    new_user() |> subscribe_to_plan(id)

    assert [%{no_list_price: 0, subscriptions: 1}] = Subscribers.audit().vs_list_price.by_currency
  end
end
