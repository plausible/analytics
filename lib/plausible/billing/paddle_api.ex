defmodule Plausible.Billing.PaddleApi do
  @update_endpoint "https://vendors.paddle.com/api/2.0/subscription/users/update"
  @get_endpoint "https://vendors.paddle.com/api/2.0/subscription/users"
  @headers [
    {"Content-type", "application/json"},
    {"Accept", "application/json"}
  ]

  def update_subscription_preview(paddle_subscription_id, new_plan_id) do
    config = get_config()

    params = %{
      vendor_id: config[:vendor_id],
      vendor_auth_code: config[:vendor_auth_code],
      subscription_id: paddle_subscription_id,
      plan_id: new_plan_id,
      prorate: true,
      keep_modifiers: true,
      bill_immediately: true,
      quantity: 1
    }

    {:ok, response} =
      HTTPoison.post(
        vendors_domain() <> "/api/2.0/subscription/preview_update",
        Jason.encode!(params),
        @headers
      )

    body = Jason.decode!(response.body)

    if body["success"] do
      {:ok, body["response"]}
    else
      {:error, body["error"]}
    end
  end

  def update_subscription(paddle_subscription_id, params) do
    config = get_config()

    params =
      Map.merge(params, %{
        vendor_id: config[:vendor_id],
        vendor_auth_code: config[:vendor_auth_code],
        subscription_id: paddle_subscription_id,
        prorate: true,
        keep_modifiers: true,
        bill_immediately: true,
        quantity: 1
      })

    {:ok, response} = HTTPoison.post(@update_endpoint, Jason.encode!(params), @headers)
    body = Jason.decode!(response.body)

    if body["success"] do
      {:ok, body["response"]}
    else
      {:error, body["error"]}
    end
  end

  def get_subscription(paddle_subscription_id) do
    config = get_config()

    params = %{
      vendor_id: config[:vendor_id],
      vendor_auth_code: config[:vendor_auth_code],
      subscription_id: paddle_subscription_id
    }

    {:ok, response} = HTTPoison.post(@get_endpoint, Jason.encode!(params), @headers)
    body = Jason.decode!(response.body)

    if body["success"] do
      [subscription] = body["response"]
      {:ok, subscription}
    else
      {:error, body["error"]}
    end
  end

  def get_invoices(nil), do: {:error, :no_subscription}

  def get_invoices(subscription) do
    config = get_config()

    params = %{
      vendor_id: config[:vendor_id],
      vendor_auth_code: config[:vendor_auth_code],
      subscription_id: subscription.paddle_subscription_id,
      is_paid: 1,
      from: Timex.shift(Timex.today(), years: -5) |> Timex.format!("{YYYY}-{0M}-{0D}"),
      to: Timex.shift(Timex.today(), days: 1) |> Timex.format!("{YYYY}-{0M}-{0D}")
    }

    case HTTPoison.post(invoices_endpoint(), Jason.encode!(params), @headers) do
      {:ok, response} ->
        body = Jason.decode!(response.body)

        if body["success"] && body["response"] != [] do
          body["response"] |> last_12_invoices()
        else
          {:error, :request_failed}
        end

      {:error, _reason} ->
        {:error, :request_failed}
    end
  end

  defp invoices_endpoint() do
    case Application.get_env(:plausible, :environment) do
      "dev" -> "https://sandbox-vendors.paddle.com/api/2.0/subscription/payments"
      _ -> "https://vendors.paddle.com/api/2.0/subscription/payments"
    end
  end

  defp last_12_invoices(invoice_list) do
    Enum.sort(invoice_list, fn %{"payout_date" => d1}, %{"payout_date" => d2} ->
      Date.compare(Date.from_iso8601!(d1), Date.from_iso8601!(d2)) == :gt
    end)
    |> Enum.take(12)
  end

  def checkout_domain() do
    case Application.get_env(:plausible, :environment) do
      "dev" -> "https://sandbox-checkout.paddle.com"
      _ -> "https://checkout.paddle.com"
    end
  end

  def vendors_domain() do
    case Application.get_env(:plausible, :environment) do
      "dev" -> "https://sandbox-vendors.paddle.com"
      _ -> "https://vendors.paddle.com"
    end
  end

  defp get_config() do
    Application.get_env(:plausible, :paddle)
  end
end
