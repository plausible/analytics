defmodule Plausible.Billing.PaddleBilling.Migration do
  @moduledoc """
  Tooling for migrating from Paddle Classic to Paddle Billing.

  - Products reflect plan definitions from JSON files 1:1
  - Prices for each product reflect plans from Paddle Classic
  - Enterprise plans are linked to a single product, each with a custom price
  - Legacy classic plans with a single currency are mapped to a respective 
    price accordingly, without overrides
  """

  use Plausible.Repo

  alias Plausible.Billing.{EnterprisePlan, Subscription}
  alias Plausible.Billing.PaddleBilling
  alias Plausible.Billing.PaddleClassic

  @enterprise_product_name "Plausible Enterprise"

  currency_parity_file =
    Application.app_dir(:plausible, ["priv", "classic_plan_currency_parity.json"])

  prices_file =
    Application.app_dir(:plausible, ["priv", "plan_prices.json"])

  @external_resource currency_parity_file
  @external_resource prices_file
  @currency_parity_file currency_parity_file
  @prices_file prices_file

  @doc """
  Creates the products and prices for the standard plans that don't exist in
  Paddle Billing yet.

  With `overwrite?` set, the plans that already exist are updated as well:
  their products and prices are patched to match the current plan
  definitions, and prices that are missing are created.

  Returns the mapping of every Classic plan id to its Billing product and
  price ids, whether they were created now or found in Paddle, so repeated
  runs return the same mapping.

  The generation of a plan is only put in the price description, which is
  internal. Product and price names are displayed to customers.
  """
  def sync_standard(overwrite? \\ false) do
    canonical_plans = Plausible.Billing.Plans.all()
    {:ok, existing_products} = PaddleBilling.api().list_products()

    product_by_classic_plan_id =
      for product <- existing_products,
          classic_plan_id <- canonical_plan_ids(product),
          into: %{} do
        {classic_plan_id, product}
      end

    context = %{
      multi_currency_plans:
        @currency_parity_file
        |> File.read!()
        |> JSON.decode!()
        |> Map.fetch!("multi_currency_classic_paddle_plan_ids")
        |> MapSet.new(),
      plan_prices: @prices_file |> File.read!() |> JSON.decode!()
    }

    existing_mapping = classic_plan_mapping(existing_products)

    Enum.reduce(canonical_plans, existing_mapping, fn canonical_plan, acc ->
      Process.sleep(1_000)
      IO.write(".")

      existing_product =
        Map.get(product_by_classic_plan_id, canonical_plan.monthly_product_id) ||
          Map.get(product_by_classic_plan_id, canonical_plan.yearly_product_id)

      cond do
        is_nil(existing_product) -> create_product(canonical_plan, context, acc)
        overwrite? -> update_product(existing_product, canonical_plan, context, acc)
        true -> acc
      end
    end)
  end

  @doc """
  Creates a custom price for every enterprise plan in the database that
  doesn't have one in Paddle Billing yet, all under a single custom
  "Enterprise" product.

  Enterprise plans are always single currency, but the database doesn't
  record which one. The currency and the amount are read from the plan in
  Paddle Classic, by `paddle_plan_id`. Plans that Classic doesn't know, or
  that don't have exactly one recurring price, are reported with a raise
  before anything is written to Paddle Billing.

  Plans without a Classic counterpart (manual subscriptions) are skipped, and
  so are duplicates: teams sharing a `paddle_plan_id` share its price.

  With `overwrite?` set, existing prices (and the product) are updated as well.

  Returns the mapping of every Classic plan id to its Billing product and
  price ids, like `sync_standard/1`.
  """
  def sync_enterprise(overwrite? \\ false) do
    enterprise_plans = enterprise_plans_with_prices()

    {:ok, existing_products} = PaddleBilling.api().list_products()

    enterprise_product =
      Enum.find(existing_products, &(get_in(&1, ["custom_data", "enterprise"]) == true))

    {product_id, existing_mapping} =
      case enterprise_product do
        nil ->
          {:ok, product} =
            PaddleBilling.api().create_product(
              @enterprise_product_name,
              enterprise_product_data(),
              enterprise?: true
            )

          {product["id"], %{}}

        product ->
          if overwrite? do
            {:ok, _} =
              PaddleBilling.api().update_product(product["id"],
                name: @enterprise_product_name,
                custom_data: enterprise_product_data()
              )
          end

          {product["id"], classic_plan_mapping([product])}
      end

    Enum.reduce(enterprise_plans, existing_mapping, fn {plan, price}, acc ->
      Process.sleep(1_000)
      IO.write(".")

      sync_enterprise_price(product_id, plan, price, acc, overwrite?)
    end)
  end

  defp sync_enterprise_price(product_id, plan, price, acc, overwrite?) do
    description = enterprise_price_description(plan)

    custom_data = %{
      "paddle_classic_plan_id" => plan.paddle_plan_id,
      "canonical_enterprise_plan" => Map.from_struct(plan)
    }

    billing_price =
      case Map.get(acc, plan.paddle_plan_id) do
        %{billing_price_id: price_id} when overwrite? ->
          {:ok, billing_price} =
            PaddleBilling.api().update_price(price_id,
              description: description,
              price: price,
              custom_data: custom_data
            )

          billing_price

        %{billing_price_id: price_id} ->
          %{"id" => price_id}

        nil ->
          {:ok, billing_price} =
            PaddleBilling.api().create_price(product_id, description,
              interval: plan.billing_interval,
              price: price,
              enterprise?: true,
              custom_data: custom_data
            )

          billing_price
      end

    Map.put(acc, plan.paddle_plan_id, %{
      billing_product_id: product_id,
      billing_price_id: billing_price["id"]
    })
  end

  # One entry per Classic plan, with its price read from Classic
  defp enterprise_plans_with_prices() do
    manual_plan_id = Subscription.manual_plan_id()

    enterprise_plans =
      Repo.all(
        from ep in EnterprisePlan,
          where: ep.paddle_plan_id != ^manual_plan_id,
          order_by: ep.id
      )
      |> Enum.uniq_by(& &1.paddle_plan_id)

    {:ok, classic_plans} = PaddleClassic.api().list_plans()
    classic_plans_by_id = Map.new(classic_plans, &{to_string(&1["id"]), &1})

    resolved =
      for plan <- enterprise_plans do
        case classic_price(Map.get(classic_plans_by_id, plan.paddle_plan_id)) do
          {:ok, price} -> {:ok, {plan, price}}
          {:error, reason} -> {:error, {plan.paddle_plan_id, reason}}
        end
      end

    case for({:error, problem} <- resolved, do: problem) do
      [] ->
        for {:ok, plan_with_price} <- resolved, do: plan_with_price

      problems ->
        raise "Enterprise plans that can't be priced from Paddle Classic: #{inspect(problems)}"
    end
  end

  # Enterprise plans are assumed to be single currency, the currency is
  # whichever one the Classic plan is priced in.
  defp classic_price(nil), do: {:error, :not_in_classic}

  defp classic_price(%{"recurring_price" => %{} = prices}) when map_size(prices) == 1 do
    [{currency, amount}] = Map.to_list(prices)

    case Money.new(currency, to_string(amount)) do
      %Money{} = money -> {:ok, money}
      {:error, _} -> {:error, {:invalid_price, currency, amount}}
    end
  end

  defp classic_price(%{"recurring_price" => %{} = prices}) when map_size(prices) > 1,
    do: {:error, {:several_currencies, prices |> Map.keys() |> Enum.sort()}}

  defp classic_price(_plan), do: {:error, :no_recurring_price}

  defp enterprise_product_data(), do: %{"enterprise" => true}

  # Internal, like the standard price descriptions
  defp enterprise_price_description(plan) do
    "[enterprise] #{plan.billing_interval} (Classic plan #{plan.paddle_plan_id})"
  end

  defp create_product(canonical_plan, context, acc) do
    {:ok, product} =
      PaddleBilling.api().create_product(
        product_name(canonical_plan),
        product_data(canonical_plan),
        description: product_description(canonical_plan)
      )

    sync_prices(product["id"], canonical_plan, context, acc, false)
  end

  defp update_product(existing_product, canonical_plan, context, acc) do
    {:ok, product} =
      PaddleBilling.api().update_product(existing_product["id"],
        name: product_name(canonical_plan),
        custom_data: product_data(canonical_plan),
        description: product_description(canonical_plan)
      )

    sync_prices(product["id"], canonical_plan, context, acc, true)
  end

  # Updates the price the mapping already knows about when `update?` is set,
  # otherwise (or when there is none) creates it.
  defp sync_prices(product_id, canonical_plan, context, acc, update?) do
    # Some plans only come in one interval
    [monthly: canonical_plan.monthly_product_id, yearly: canonical_plan.yearly_product_id]
    |> Enum.reject(fn {_interval, classic_plan_id} -> is_nil(classic_plan_id) end)
    |> Enum.reduce(acc, fn {interval, classic_plan_id}, acc ->
      description = price_description(canonical_plan, interval)
      price = Money.new!(Map.fetch!(context.plan_prices, classic_plan_id), :USD)
      overrides? = MapSet.member?(context.multi_currency_plans, classic_plan_id)
      custom_data = %{"paddle_classic_plan_id" => classic_plan_id}

      billing_price =
        case update? && Map.get(acc, classic_plan_id) do
          %{billing_price_id: price_id} ->
            {:ok, billing_price} =
              PaddleBilling.api().update_price(price_id,
                description: description,
                price: price,
                overrides?: overrides?,
                custom_data: custom_data
              )

            billing_price

          _none ->
            opts = [
              interval: interval,
              overrides?: overrides?,
              price: price,
              custom_data: custom_data
            ]

            {:ok, billing_price} = PaddleBilling.api().create_price(product_id, description, opts)
            billing_price
        end

      Map.put(acc, classic_plan_id, %{
        billing_product_id: product_id,
        billing_price_id: billing_price["id"]
      })
    end)
  end

  defp product_data(canonical_plan), do: %{canonical_plan: Map.from_struct(canonical_plan)}

  defp canonical_plan_ids(product) do
    canonical_plan = get_in(product, ["custom_data", "canonical_plan"]) || %{}

    Enum.reject(
      [canonical_plan["monthly_product_id"], canonical_plan["yearly_product_id"]],
      &is_nil/1
    )
  end

  # Prices link back to Classic through their `paddle_classic_plan_id`
  defp classic_plan_mapping(products) do
    for product <- products,
        price <- product["prices"] || [],
        classic_plan_id = get_in(price, ["custom_data", "paddle_classic_plan_id"]),
        into: %{} do
      {classic_plan_id, %{billing_product_id: product["id"], billing_price_id: price["id"]}}
    end
  end

  # Internal, not shown to customers, unlike product and price names. Plans of
  # different generations share their names.
  defp price_description(plan, interval) do
    "[v#{plan.generation}] #{interval} #{product_name(plan)}"
  end

  defp product_name(plan) do
    prefix = plan.kind |> to_string() |> String.capitalize()

    "#{prefix} (#{plan.volume})"
  end

  defp product_description(plan) do
    "[v#{plan.generation}] #{product_name(plan)}"
  end
end
