defmodule Plausible.Billing.DevPaddleApiMock do
  @moduledoc """
  This module mocks API requests made to Paddle in the :dev environment.

  Note that not creating and cancelling subscriptions are handled separately. See
  `Plausible.Billing.DevSubscriptions`.
  """

  @prices_file_path Application.app_dir(:plausible, ["priv", "plan_prices.json"])
  @prices File.read!(@prices_file_path) |> Jason.decode!()

  def all_prices() do
    enterprise_plan_prices =
      Plausible.Billing.EnterprisePlan
      |> Plausible.Repo.all()
      |> Map.new(fn ep -> {ep.paddle_plan_id, 123} end)

    Map.merge(@prices, enterprise_plan_prices)
  end

  @doc """
  Mocks the real `Plausible.Billing.PaddleApi.fetch_prices`, but:

  1. instead of filtering by a list of product IDs simply returns the prices for
     all plans

  2. always returns "EUR" as the currency

  The prices of all production plans are duplicated into `/priv/plan_prices.json`
  in order to avoid relying on Paddle in the :dev env.
  """
  def fetch_prices(_, _) do
    prices_as_money =
      all_prices()
      |> Map.new(fn {plan_id, price} ->
        {plan_id, Money.from_integer(price * 100, "EUR")}
      end)

    {:ok, prices_as_money}
  end

  def update_subscription_preview(paddle_subscription_id, new_plan_id) do
    {:ok,
     %{
       "immediate_payment" => %{
         "amount" => all_prices()[new_plan_id],
         "currency" => "EUR",
         "date" => Date.utc_today() |> Date.to_iso8601()
       },
       "next_payment" => %{
         "amount" => all_prices()[new_plan_id],
         "currency" => "EUR",
         "date" => Date.utc_today() |> Date.shift(month: 1) |> Date.to_iso8601()
       },
       "plan_id" => String.to_integer(new_plan_id),
       "subscription_id" => paddle_subscription_id
     }}
  end

  def update_subscription(_, %{plan_id: plan_id}) do
    {:ok,
     %{
       "next_payment" => %{
         "amount" => all_prices()[plan_id],
         "date" => Date.utc_today() |> Date.shift(month: 1) |> Date.to_iso8601()
       },
       "plan_id" => String.to_integer(plan_id)
     }}
  end

  def get_invoices(_), do: {:error, :no_invoices}
end
