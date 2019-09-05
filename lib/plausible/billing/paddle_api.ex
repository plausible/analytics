defmodule Plausible.Billing.PaddleApi do
  @update_endpoint "https://vendors.paddle.com/api/2.0/subscription/users/update"
  @get_endpoint "https://vendors.paddle.com/api/2.0/subscription/users"
  @vendor_id "49430"
  @vendor_auth_code System.get_env("PADDLE_VENDOR_AUTH_CODE")
  @headers [
    {"Content-type", "application/json"},
    {"Accept", "application/json"}
  ]

  def update_subscription(paddle_subscription_id, params) do
    params = Map.merge(params, %{
      vendor_id: @vendor_id,
      vendor_auth_code: @vendor_auth_code,
      subscription_id: paddle_subscription_id,
      quantity: 1
    })

    {:ok, response} = HTTPoison.post(@update_endpoint, Poison.encode!(params), @headers)
    body = Poison.decode!(response.body)

    if body["success"] do
      {:ok, body["response"]}
    else
      {:error, body["error"]}
    end
  end

  def get_subscription(paddle_subscription_id) do
    params = %{
      vendor_id: @vendor_id,
      vendor_auth_code: @vendor_auth_code,
      subscription_id: paddle_subscription_id
    }

    {:ok, response} = HTTPoison.post(@get_endpoint, Poison.encode!(params), @headers)
    body = Poison.decode!(response.body)

    if body["success"] do
      [subscription] = body["response"]
      {:ok, subscription}
    else
      {:error, body["error"]}
    end
  end
end
