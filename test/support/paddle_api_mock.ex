defmodule Plausible.PaddleApi.Mock do
  def get_subscription(_) do
    {:ok,
     %{
       "next_payment" => %{
         "date" => "2019-07-10",
         "amount" => 6
       },
       "last_payment" => %{
         "date" => "2019-06-10",
         "amount" => 6
       }
     }}
  end

  def update_subscription(_, %{plan_id: new_plan_id}) do
    new_plan_id = String.to_integer(new_plan_id)

    {:ok,
     %{
       "plan_id" => new_plan_id,
       "next_payment" => %{
         "date" => "2019-07-10",
         "amount" => 6
       }
     }}
  end

  def update_subscription_preview(_user, _new_plan_id) do
    {:ok,
     %{
       "immediate_payment" => %{
         "amount" => -72.6,
         "currency" => "EUR",
         "date" => "2023-11-05"
       },
       "next_payment" => %{
         "amount" => 47.19,
         "currency" => "EUR",
         "date" => "2023-12-05"
       },
       "plan_id" => 63_852,
       "subscription_id" => 600_279,
       "user_id" => 666_317
     }}
  end

  def get_invoices(nil), do: {:error, :no_invoices}
  def get_invoices(%{paddle_subscription_id: nil}), do: {:error, :no_invoices}

  def get_invoices(subscription) do
    case subscription.paddle_subscription_id do
      "invalid_subscription_id" ->
        {:error, :request_failed}

      _ ->
        {:ok,
         [
           %{
             "amount" => 11.11,
             "currency" => "EUR",
             "payout_date" => "2020-12-24",
             "receipt_url" => "https://some-receipt-url.com"
           },
           %{
             "amount" => 22,
             "currency" => "USD",
             "payout_date" => "2020-11-24",
             "receipt_url" => "https://other-receipt-url.com"
           }
         ]}
    end
  end

  # to give a reasonable testing structure for monthly and yearly plan
  # prices, this function returns prices with the following logic:
  # 10, 100, 20, 200, 30, 300, ...and so on.
  def fetch_prices([_ | _] = product_ids, _customer_ip) do
    {prices, _index} =
      Enum.reduce(product_ids, {%{}, 1}, fn p, {acc, i} ->
        price =
          if rem(i, 2) == 1,
            do: ceil(i / 2.0) * 10.0,
            else: ceil(i / 2.0) * 100.0

        {Map.put(acc, p, Money.from_float!(:EUR, price)), i + 1}
      end)

    {:ok, prices}
  end
end
