defmodule Plausible.Billing.PaddleApi do
  @endpoint "https://vendors.paddle.com/api/2.0/subscription/users/update"
  @vendor_id "49430"
  @vendor_auth_code "00e75d18fde1457171b73723ecf54c4026f9b0047e70b6dbff"
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

    {:ok, response} = HTTPoison.post(@endpoint, Poison.encode!(params), @headers)
    body = Poison.decode!(response.body)

    if body["success"] do
      {:ok, body["response"]}
    else
      {:error, body["error"]}
    end
  end
end
