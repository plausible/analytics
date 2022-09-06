defmodule Plausible.Billing.PaddleApi do
  alias Plausible.HTTPClient

  @headers [
    {"content-type", "application/json"},
    {"accept", "application/json"}
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

    case HTTPClient.post(preview_update_url(), @headers, params) do
      {:ok, response} ->
        body = Jason.decode!(response.body)

        if body["success"] do
          {:ok, body["response"]}
        else
          {:error, body["error"]}
        end

      {:error, error} ->
        {:error, error}
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

    case HTTPClient.post(update_subscription_url(), @headers, params) do
      {:ok, response} ->
        body = Jason.decode!(response.body)

        if body["success"] do
          {:ok, body["response"]}
        else
          {:error, body["error"]}
        end

      {:error, %{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_subscription(paddle_subscription_id) do
    config = get_config()

    params = %{
      vendor_id: config[:vendor_id],
      vendor_auth_code: config[:vendor_auth_code],
      subscription_id: paddle_subscription_id
    }

    case HTTPClient.post(get_subscription_url(), @headers, params) do
      {:ok, response} ->
        body = Jason.decode!(response.body)

        if body["success"] do
          [subscription] = body["response"]
          {:ok, subscription}
        else
          {:error, body["error"]}
        end

      {:error, %{reason: reason}} ->
        {:error, reason}
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

    case HTTPClient.post(invoices_url(), @headers, params) do
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

  defp invoices_url() do
    Path.join(vendors_domain(), "/api/2.0/subscription/payments")
  end

  defp preview_update_url() do
    Path.join(vendors_domain(), "/api/2.0/subscription/preview_update")
  end

  defp update_subscription_url() do
    Path.join(vendors_domain(), "/api/2.0/subscription/users/update")
  end

  defp get_subscription_url() do
    Path.join(vendors_domain(), "/api/2.0/subscription/users")
  end
end
