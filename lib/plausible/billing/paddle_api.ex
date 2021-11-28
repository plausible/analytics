defmodule Plausible.Billing.PaddleApi do
  @update_preview_endpoint "https://vendors.paddle.com/api/2.0/subscription/preview_update"
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

    {:ok, response} = HTTPoison.post(@update_preview_endpoint, Jason.encode!(params), @headers)
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

  defp get_config() do
    Application.get_env(:plausible, :paddle)
  end
end
