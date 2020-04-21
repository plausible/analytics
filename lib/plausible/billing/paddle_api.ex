defmodule Plausible.Billing.PaddleApi do
  @update_preview_endpoint "https://vendors.paddle.com/api/2.0/subscription/preview_update"
  @update_endpoint "https://vendors.paddle.com/api/2.0/subscription/users/update"
  @get_endpoint "https://vendors.paddle.com/api/2.0/subscription/users"
  @vendor_id Keyword.fetch!(Application.get_env(:plausible, :paddle), :vendor_id)
  @vendor_auth_code Keyword.fetch!(Application.get_env(:plausible, :paddle), :vendor_auth_code)
  @headers [
    {"Content-type", "application/json"},
    {"Accept", "application/json"}
  ]

  def update_subscription_preview(paddle_subscription_id, new_plan_id) do
    params = %{
      vendor_id: @vendor_id,
      vendor_auth_code: @vendor_auth_code,
      subscription_id: paddle_subscription_id,
      plan_id: new_plan_id,
      prorate: true,
      keep_modifiers: true,
      bill_immediately: true,
      quantity: 1
    }

    {:ok, response} = HTTPoison.post(@update_preview_endpoint, Poison.encode!(params), @headers)
    body = Poison.decode!(response.body)

    if body["success"] do
      {:ok, body["response"]}
    else
      {:error, body["error"]}
    end
  end

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
