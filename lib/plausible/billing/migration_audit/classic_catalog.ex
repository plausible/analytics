defmodule Plausible.Billing.MigrationAudit.ClassicCatalog do
  @moduledoc """
  The part of the Paddle Billing migration audit that needs Paddle Classic: the
  plan catalog (which plans have prices in several currencies, and which kind of
  plan each one is) and subscription modifiers. It only makes read-only calls
  (`list_plans` and `list_modifiers`) and the output is aggregated: plan names
  and descriptions (customer names, mostly) are never included.

  See `Plausible.Billing.MigrationAudit` for how to run it.

  The request and response shapes follow Paddle's
  [Subscription API reference](https://classic.paddle.com/api-reference/reference/subscription-api)
  (`POST /2.0/subscription/plans` and `/modifiers`). They haven't been run against the
  production account yet, so parsing is forgiving: entries that can't be understood
  are counted (`:without_recurring_price`, `:recurrence_unknown`, `:zero_or_unparseable`)
  rather than raising.
  """

  use Plausible.Repo

  import Ecto.Query, only: [from: 2]

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.{EnterprisePlan, PaddleClassic, Plans, Subscription}
  alias Plausible.Billing.Subscription.Status

  @doc """
  Fetches the catalog and the modifiers from Paddle Classic and summarises them.

  Returns `{:ok, %{plans: ..., modifiers: ...}}`, or `{:error, {:plans | :modifiers, reason}}`.

  Options:

    * `:api` - the Classic API client (default: `PaddleClassic.api()`). Needs
      `list_plans/0` and `list_modifiers/0`.
    * `:plans`, `:modifiers` - already fetched lists, to skip the calls.
    * `:today` - date for "inside the paid period" (default: today, UTC).
  """
  @spec audit(Keyword.t()) :: {:ok, map()} | {:error, {atom(), term()}}
  def audit(opts \\ []) do
    api = Keyword.get_lazy(opts, :api, &PaddleClassic.api/0)
    today = Keyword.get(opts, :today, Date.utc_today())

    with {:ok, plans} <- fetch(opts, :plans, fn -> api.list_plans() end),
         {:ok, modifiers} <- fetch(opts, :modifiers, fn -> api.list_modifiers() end) do
      live = live_subscriptions(today)

      {:ok,
       %{plans: summarise_plans(plans, live), modifiers: summarise_modifiers(modifiers, live)}}
    end
  end

  defp fetch(opts, key, fun) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> with {:error, reason} <- fun.(), do: {:error, {key, reason}}
    end
  end

  # plan id and subscription id of live subscriptions (see MigrationAudit.plan_resolution/1)
  defp live_subscriptions(today) do
    live = [Status.active(), Status.past_due(), Status.paused()]

    from(s in Subscription,
      where: s.status in ^live or (s.status == ^Status.deleted() and s.next_bill_date >= ^today),
      select: {s.paddle_plan_id, s.paddle_subscription_id}
    )
    |> Repo.all()
  end

  # --- plans -----------------------------------------------------------------------

  defp summarise_plans(plans, live) do
    static_ids = MapSet.new(Plans.all(), & &1.monthly_product_id) |> add_yearly_ids()

    enterprise_ids =
      from(ep in EnterprisePlan, distinct: true, select: ep.paddle_plan_id)
      |> Repo.all()
      |> MapSet.new()

    live_plan_ids = live |> Enum.map(&elem(&1, 0)) |> MapSet.new()

    described =
      Enum.map(plans, fn plan ->
        id = to_string(plan["id"])
        prices = recurring_prices(plan)

        %{
          id: id,
          origin: origin(id, static_ids, enterprise_ids),
          prices: prices,
          currencies: prices |> Map.keys() |> Enum.sort(),
          parity?: parity?(prices),
          billing: {plan["billing_type"], plan["billing_period"]},
          trial?: (plan["trial_days"] || 0) > 0,
          live?: MapSet.member?(live_plan_ids, id)
        }
      end)

    catalog_ids = MapSet.new(described, & &1.id)

    multi = Enum.filter(described, &(length(&1.currencies) > 1))

    %{
      total: length(described),
      by_origin: Enum.frequencies_by(described, & &1.origin),
      with_live_subscription_by_origin:
        described |> Enum.filter(& &1.live?) |> Enum.frequencies_by(& &1.origin),
      without_recurring_price: Enum.count(described, &(&1.prices == %{})),
      with_trial_days: Enum.count(described, & &1.trial?),
      by_billing_period:
        described
        |> counts(& &1.billing)
        |> Enum.map(fn {{type, period}, n} ->
          %{billing_type: type, billing_period: period, plans: n}
        end),
      single_currency: length(described) - length(multi),
      multi_currency: length(multi),
      multi_currency_by_origin: Enum.frequencies_by(multi, & &1.origin),
      multi_currency_parity: Enum.count(multi, & &1.parity?),
      multi_currency_differing: Enum.count(multi, &(not &1.parity?)),
      currency_sets:
        described
        |> counts(& &1.currencies)
        |> Enum.map(fn {currencies, n} -> %{currencies: currencies, plans: n} end),
      differing_examples:
        multi
        |> Enum.reject(& &1.parity?)
        |> Enum.take(5)
        |> Enum.map(&%{plan_id: &1.id, origin: &1.origin, prices: &1.prices}),
      live_plan_ids_missing_from_catalog:
        live_plan_ids
        |> Enum.reject(
          &(&1 in [Subscription.manual_plan_id(), "free_10k"] or MapSet.member?(catalog_ids, &1))
        )
        |> Enum.sort()
    }
  end

  defp add_yearly_ids(set) do
    Enum.reduce(Plans.all(), set, fn plan, acc ->
      MapSet.put(acc, plan.yearly_product_id)
    end)
  end

  defp origin(id, static_ids, enterprise_ids) do
    cond do
      MapSet.member?(static_ids, id) -> :static
      MapSet.member?(enterprise_ids, id) -> :enterprise
      true -> :other
    end
  end

  defp recurring_prices(%{"recurring_price" => %{} = prices}) do
    for {currency, amount} <- prices, {:ok, decimal} <- [to_decimal(amount)], into: %{} do
      {currency, Decimal.to_string(Decimal.round(decimal, 2), :normal)}
    end
  end

  defp recurring_prices(_plan), do: %{}

  defp parity?(prices) do
    prices
    |> Map.values()
    |> Enum.map(&Decimal.new/1)
    |> Enum.uniq_by(&Decimal.to_string/1)
    |> length() <= 1
  end

  # --- modifiers -----------------------------------------------------------------------

  defp summarise_modifiers(modifiers, live) do
    live_subscription_ids = live |> Enum.map(&to_string(elem(&1, 1))) |> MapSet.new()

    described =
      Enum.map(modifiers, fn modifier ->
        %{
          subscription_id: to_string(modifier["subscription_id"]),
          currency: modifier["currency"],
          amount: to_decimal(modifier["amount"]),
          recurring?: recurring?(modifier)
        }
      end)

    subscription_ids = described |> Enum.map(& &1.subscription_id) |> Enum.uniq()

    per_subscription = Enum.frequencies_by(described, & &1.subscription_id)

    %{
      total: length(described),
      recurring: Enum.count(described, &(&1.recurring? == true)),
      one_time: Enum.count(described, &(&1.recurring? == false)),
      recurrence_unknown: Enum.count(described, &(&1.recurring? == :unknown)),
      subscriptions_with_modifiers: length(subscription_ids),
      of_which_live: Enum.count(subscription_ids, &MapSet.member?(live_subscription_ids, &1)),
      max_modifiers_on_one_subscription:
        per_subscription |> Map.values() |> Enum.max(fn -> 0 end),
      discounts: Enum.count(described, &sign?(&1.amount, :lt)),
      surcharges: Enum.count(described, &sign?(&1.amount, :gt)),
      zero_or_unparseable:
        Enum.count(described, &(not sign?(&1.amount, :lt) and not sign?(&1.amount, :gt))),
      by_currency:
        described
        |> Enum.group_by(& &1.currency)
        |> Enum.map(fn {currency, group} ->
          amounts = for %{amount: {:ok, a}} <- group, do: a

          %{
            currency: currency,
            modifiers: length(group),
            net_amount:
              case amounts do
                [] ->
                  nil

                amounts ->
                  amounts
                  |> Enum.reduce(&Decimal.add/2)
                  |> Decimal.round(2)
                  |> Decimal.to_string(:normal)
              end
          }
        end)
        |> Enum.sort_by(&{-&1.modifiers, &1.currency || ""}),
      not_covered:
        "One-time charges made outside modifiers aren't returned by the modifiers list. " <>
          "Coupons aren't stored on our side or returned here."
    }
  end

  defp recurring?(%{"is_recurring" => value}) when is_boolean(value), do: value
  defp recurring?(_), do: :unknown

  defp sign?({:ok, amount}, sign), do: Decimal.compare(amount, 0) == sign
  defp sign?(_, _sign), do: false

  # --- helpers -----------------------------------------------------------------------

  defp counts(items, fun) do
    items |> Enum.frequencies_by(fun) |> Enum.sort_by(fn {key, n} -> {-n, inspect(key)} end)
  end

  defp to_decimal(value) when is_integer(value), do: {:ok, Decimal.new(value)}
  defp to_decimal(value) when is_float(value), do: {:ok, Decimal.from_float(value)}

  defp to_decimal(value) when is_binary(value) do
    case Decimal.parse(String.trim(value)) do
      {decimal, ""} -> {:ok, decimal}
      _ -> :error
    end
  end

  defp to_decimal(_), do: :error
end
