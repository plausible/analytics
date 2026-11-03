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

  def sync_standard(overwrite? \\ false) do
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

    Enum.reduce(canonical_plans, %{}, fn canonical_plan, acc ->
      monthly_exists? = MapSet.member?(existing_plan_ids, canonical_plan.monthly_product_id)
      yearly_exists? = MapSet.member?(existing_plan_ids, canonical_plan.yearly_product_id)

      if not monthly_exists? and not yearly_exists? do
        product_data = %{
          canonical_plan: canonical_plan |> Map.from_struct() |> JSON.encode!()
        }

        product_name = plan_name(canonical_plan)

        {:ok, product} = PaddleBilling.api().create_product(product_name, product_data)

        monthly_price =
          Money.new!(Map.fetch!(plan_prices, canonical_plan.monthly_product_id), :USD)

        monthly_overrides? =
          MapSet.member?(multi_currency_plans, canonical_plan.monthly_product_id)

        monthly_opts = [
          interval: :monthly,
          overrides?: monthly_overrides?,
          price: monthly_price,
          custom_data: %{"paddle_classic_plan_id" => canonical_plan.monthly_product_id}
        ]

        {:ok, monthly_price} =
          PaddleBilling.api().create_price(
            product["id"],
            "#{product_name} monthly",
            monthly_opts
          )

        yearly_price = Money.new!(Map.fetch!(plan_prices, canonical_plan.yearly_product_id), :USD)
        yearly_overrides? = MapSet.member?(multi_currency_plans, canonical_plan.yearly_product_id)

        yearly_opts = [
          interval: :yearly,
          overrides?: yearly_overrides?,
          price: yearly_price,
          custom_data: %{"paddle_classic_plan_id" => canonical_plan.yearly_product_id}
        ]

        {:ok, yearly_price} =
          PaddleBilling.api().create_price(product["id"], "#{product_name} yearly", yearly_opts)

        acc
        |> Map.put(canonical_plan.monthly_plan_id, %{
          billing_product_id: product["id"],
          billing_price_id: monthly_price["id"]
        })
        |> Map.put(canonical_plan.yearly_plan_id, %{
          billing_product_id: product["id"],
          billing_price_id: yearly_price["id"]
        })
      end
    end)
  end

  defp plan_name(plan) do
    prefix = plan.kind |> to_string() |> String.capitalize()

    "#{prefix} (#{plan.volume})"
  end
end
