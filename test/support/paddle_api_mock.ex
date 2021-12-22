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

  def get_invoices(nil), do: {:error, :no_subscription}

  def get_invoices(subscription) do
    case subscription.paddle_subscription_id do
      "invalid_subscription_id" ->
        {:error, :request_failed}

      _ ->
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
        ]
    end
  end
end
