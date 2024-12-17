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
        if response.body["success"] do
          {:ok, response.body["response"]}
        else
          {:error, response.body["error"]}
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
        if response.body["success"] do
          {:ok, response.body["response"]}
        else
          {:error, response.body["error"]}
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
        if response.body["success"] do
          [subscription] = response.body["response"]
          {:ok, subscription}
        else
          {:error, response.body["error"]}
        end

      {:error, %{reason: reason}} ->
        {:error, reason}
    end
  end

  @spec get_invoices(Plausible.Billing.Subscription.t() | nil) ::
          {:ok, list()}
          | {:error, :request_failed}
          | {:error, :no_invoices}
  def get_invoices(nil), do: {:error, :no_invoices}
  def get_invoices(%{paddle_subscription_id: nil}), do: {:error, :no_invoices}

  def get_invoices(subscription) do
    config = get_config()

    params = %{
      vendor_id: config[:vendor_id],
      vendor_auth_code: config[:vendor_auth_code],
      subscription_id: subscription.paddle_subscription_id,
      is_paid: 1,
      from: Date.shift(Date.utc_today(), year: -5) |> Calendar.strftime("%Y-%m-%d"),
      to: Date.shift(Date.utc_today(), day: 1) |> Calendar.strftime("%Y-%m-%d")
    }

    with {:ok, %{body: body}} <- HTTPClient.post(invoices_url(), @headers, params),
         true <- Map.get(body, "success"),
         [_ | _] = response <- Map.get(body, "response") do
      Enum.sort(response, fn %{"payout_date" => d1}, %{"payout_date" => d2} ->
        Date.compare(Date.from_iso8601!(d1), Date.from_iso8601!(d2)) == :gt
      end)
      |> then(&{:ok, &1})
    else
      error ->
        Sentry.capture_message("Failed to retrieve invoices from Paddle",
          extra: %{extra: error, params: params, invoices_url: invoices_url()}
        )

        {:error, :request_failed}
    end
  end

  def fetch_prices([_ | _] = product_ids, customer_ip) do
    params = %{product_ids: Enum.join(product_ids, ","), customer_ip: customer_ip}

    case HTTPClient.impl().get(prices_url(), @headers, params) do
      {:ok, %{body: %{"success" => true, "response" => %{"products" => products}}}} ->
        products =
          Enum.into(products, %{}, fn %{
                                        "currency" => currency,
                                        "price" => %{"net" => net_price},
                                        "product_id" => product_id
                                      } ->
            {Integer.to_string(product_id), Money.from_float!(currency, net_price)}
          end)

        {:ok, products}

      {:ok, %{body: body}} ->
        Sentry.capture_message("Paddle API: Unexpected response when fetching prices",
          extra: %{api_response: body, product_ids: product_ids}
        )

        {:error, :api_error}

      {:error, %{reason: reason}} ->
        Sentry.capture_message("Paddle API: Error when fetching prices", extra: %{reason: reason})
        {:error, :api_error}
    end
  end

  def checkout_domain() do
    if Application.get_env(:plausible, :environment) in ["dev", "staging"] do
      "https://sandbox-checkout.paddle.com"
    else
      "https://checkout.paddle.com"
    end
  end

  def vendors_domain() do
    if Application.get_env(:plausible, :environment) in ["dev", "staging"] do
      "https://sandbox-vendors.paddle.com"
    else
      "https://vendors.paddle.com"
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

  defp prices_url() do
    Path.join(checkout_domain(), "/api/2.0/prices")
  end
end
