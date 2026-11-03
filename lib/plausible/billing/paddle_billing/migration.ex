defmodule Plausible.Billing.PaddleBilling.Migration do
  @moduledoc """
  Tooling for migrating from Paddle Classic to Paddle Billing.

  - Products reflect plan definitions from JSON files 1:1
  - Prices for each product reflect plans from Paddle Classic
  - Enterprise plans are linked to a single product, each with a custom price
  - Legacy classic plans with a single currency are mapped to a respective 
    price accordingly, without overrides
  """

  alias Plausible.Billing.PaddleBilling

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

  Returns the mapping of every Classic plan id to its Billing product and
  price ids, whether they were created now or found in Paddle, so repeated
  runs return the same mapping.
  """
  def sync_standard(_overwrite? \\ false) do
    canonical_plans = Plausible.Billing.Plans.all()
    {:ok, existing_products} = PaddleBilling.api().list_products()

    existing_plan_ids =
      existing_products
      |> Enum.flat_map(fn p ->
        [
          p["custom_data"]["canonical_plan"]["monthly_product_id"],
          p["custom_data"]["canonical_plan"]["yearly_product_id"]
        ]
      end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    multi_currency_plans =
      @currency_parity_file
      |> File.read!()
      |> JSON.decode!()
      |> Map.fetch!("multi_currency_classic_paddle_plan_ids")
      |> MapSet.new()

    plan_prices = @prices_file |> File.read!() |> JSON.decode!()

    existing_mapping = classic_plan_mapping(existing_products)

    Enum.reduce(canonical_plans, existing_mapping, fn canonical_plan, acc ->
      Process.sleep(1000)
      IO.write(".")

      monthly_exists? = MapSet.member?(existing_plan_ids, canonical_plan.monthly_product_id)
      yearly_exists? = MapSet.member?(existing_plan_ids, canonical_plan.yearly_product_id)

      if not monthly_exists? and not yearly_exists? do
        product_data = %{canonical_plan: Map.from_struct(canonical_plan)}
        product_name = plan_name(canonical_plan)

        {:ok, product} = PaddleBilling.api().create_product(product_name, product_data)

        # Some plans only come in one interval
        [monthly: canonical_plan.monthly_product_id, yearly: canonical_plan.yearly_product_id]
        |> Enum.reject(fn {_interval, classic_plan_id} -> is_nil(classic_plan_id) end)
        |> Enum.reduce(acc, fn {interval, classic_plan_id}, acc ->
          price = Money.new!(Map.fetch!(plan_prices, classic_plan_id), :USD)

          opts = [
            interval: interval,
            overrides?: MapSet.member?(multi_currency_plans, classic_plan_id),
            price: price,
            custom_data: %{"paddle_classic_plan_id" => classic_plan_id}
          ]

          {:ok, billing_price} =
            PaddleBilling.api().create_price(product["id"], "#{product_name} #{interval}", opts)

          Map.put(acc, classic_plan_id, %{
            billing_product_id: product["id"],
            billing_price_id: billing_price["id"]
          })
        end)
      else
        acc
      end
    end)
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

  defp plan_name(plan) do
    prefix = plan.kind |> to_string() |> String.capitalize()

    "#{prefix} (#{plan.volume})"
  end
end
