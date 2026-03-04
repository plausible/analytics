defmodule PlausibleWeb.PlainController do
  use PlausibleWeb, :controller

  alias Plausible.PlainCustomerCards

  def customer_cards(conn, params) do
    token = Application.get_env(:plausible, :plain)[:token]
    auth = get_req_header(conn, "authorization") |> List.first()

    if Plug.Crypto.secure_compare(auth || "", "Bearer #{token}") do
      email = get_in(params, ["customer", "email"])
      card_keys = Map.get(params, "cardKeys", ["customer-details"])
      json(conn, %{cards: PlainCustomerCards.build_cards(email, card_keys)})
    else
      conn |> put_status(401) |> json(%{error: "Unauthorized"})
    end
  end
end
