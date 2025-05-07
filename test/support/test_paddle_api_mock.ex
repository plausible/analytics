defmodule Plausible.Billing.TestPaddleApiMock do
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

  def fetch_prices(product_ids, customer_ip) do
    Plausible.Billing.DevPaddleApiMock.fetch_prices(product_ids, customer_ip)
  end
end
