defmodule Plausible.Billing.MigrationAudit.ClassicCatalogTest do
  use Plausible.DataCase, async: true

  alias Plausible.Billing.MigrationAudit.ClassicCatalog
  alias Plausible.Billing.Plans

  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription.Status

  @today ~D[2026-10-20]

  defmodule FailingApi do
    def list_plans(), do: {:error, :boom}
    def list_modifiers(), do: {:ok, []}
  end

  defmodule BrokenModifiersApi do
    def list_plans(), do: {:ok, []}
    def list_modifiers(), do: {:error, "nope"}
  end

  defmodule FakeApi do
    def list_plans(), do: {:ok, [%{"id" => 1, "recurring_price" => %{"USD" => "5.00"}}]}
    def list_modifiers(), do: {:ok, []}
  end

  defp static_id(),
    do: Plans.all() |> Enum.find(& &1.monthly_product_id) |> Map.fetch!(:monthly_product_id)

  defp catalog_plan(id, prices, extra \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "name" => "Secret Customer Ltd",
        "billing_type" => "month",
        "billing_period" => 1,
        "initial_price" => %{},
        "recurring_price" => prices,
        "trial_days" => 0
      },
      extra
    )
  end

  describe "plans" do
    test "classifies plans by origin and currencies, without exposing names" do
      static_id = static_id()

      new_user() |> subscribe_to_plan(static_id)
      new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: "777001")
      new_user() |> subscribe_to_plan("no-longer-in-catalog")

      plans = [
        catalog_plan(String.to_integer(static_id), %{
          "USD" => "9.00",
          "EUR" => "9.00",
          "GBP" => "9.00"
        }),
        catalog_plan(777_001, %{"USD" => "100.00"}),
        catalog_plan(777_002, %{"USD" => "9.00", "EUR" => "8.00"}, %{"trial_days" => 14}),
        catalog_plan(777_003, "not a map", %{"billing_type" => "year"})
      ]

      assert {:ok, %{plans: result}} =
               ClassicCatalog.audit(today: @today, plans: plans, modifiers: [])

      assert result.total == 4
      assert Map.new(result.by_origin) == %{static: 1, enterprise: 1, other: 2}
      assert Map.new(result.with_live_subscription_by_origin) == %{static: 1, enterprise: 1}
      assert result.single_currency == 2
      assert result.multi_currency == 2
      assert result.multi_currency_parity == 1
      assert result.multi_currency_differing == 1
      assert Map.new(result.multi_currency_by_origin) == %{static: 1, other: 1}
      assert result.without_recurring_price == 1
      assert result.with_trial_days == 1
      assert result.live_plan_ids_missing_from_catalog == ["no-longer-in-catalog"]

      assert [%{plan_id: "777002", origin: :other, prices: %{"USD" => "9.00", "EUR" => "8.00"}}] =
               result.differing_examples

      assert %{currencies: ["EUR", "GBP", "USD"], plans: 1} in result.currency_sets
      assert %{billing_type: "month", billing_period: 1, plans: 3} in result.by_billing_period

      refute inspect(result) =~ "Secret Customer"
    end

    test "a cancelled subscription still inside the paid period is live, an expired one is not" do
      id = static_id()

      new_user()
      |> subscribe_to_plan(id, status: Status.deleted(), next_bill_date: @today)

      plan = catalog_plan(String.to_integer(id), %{"USD" => "9.00"})

      assert {:ok, %{plans: %{with_live_subscription_by_origin: %{static: 1}}}} =
               ClassicCatalog.audit(today: @today, plans: [plan], modifiers: [])

      assert {:ok, %{plans: %{with_live_subscription_by_origin: %{}}}} =
               ClassicCatalog.audit(
                 today: Date.shift(@today, day: 1),
                 plans: [plan],
                 modifiers: []
               )
    end
  end

  describe "modifiers" do
    test "summarises modifiers and the subscriptions they are on" do
      new_user() |> subscribe_to_plan(static_id(), paddle_subscription_id: "5001")
      new_user() |> subscribe_to_plan(static_id(), paddle_subscription_id: "5002")

      modifiers = [
        %{
          "modifier_id" => 1,
          "subscription_id" => 5001,
          "amount" => "-2.00",
          "currency" => "USD",
          "is_recurring" => true,
          "description" => "Customer secret"
        },
        %{
          "modifier_id" => 2,
          "subscription_id" => 5001,
          "amount" => "5.00",
          "currency" => "USD",
          "is_recurring" => false
        },
        %{
          "modifier_id" => 3,
          "subscription_id" => 9999,
          "amount" => "-1.50",
          "currency" => "EUR",
          "is_recurring" => true
        },
        %{"modifier_id" => 4, "subscription_id" => 5002, "amount" => "0.00", "currency" => "USD"}
      ]

      assert {:ok, %{modifiers: result}} =
               ClassicCatalog.audit(today: @today, plans: [], modifiers: modifiers)

      assert result.total == 4
      assert result.recurring == 2
      assert result.one_time == 1
      assert result.recurrence_unknown == 1
      assert result.subscriptions_with_modifiers == 3
      assert result.of_which_live == 2
      assert result.max_modifiers_on_one_subscription == 2
      assert result.discounts == 2
      assert result.surcharges == 1
      assert result.zero_or_unparseable == 1

      assert [
               %{currency: "USD", modifiers: 3, net_amount: "3.00"},
               %{currency: "EUR", modifiers: 1, net_amount: "-1.50"}
             ] =
               result.by_currency

      refute inspect(result) =~ "secret"
    end
  end

  describe "fetching" do
    test "uses the given api module" do
      assert {:ok, %{plans: %{total: 1}}} = ClassicCatalog.audit(api: FakeApi, today: @today)
    end

    test "reports which call failed" do
      assert {:error, {:plans, :boom}} = ClassicCatalog.audit(api: FailingApi)
      assert {:error, {:modifiers, "nope"}} = ClassicCatalog.audit(api: BrokenModifiersApi)
    end
  end
end
