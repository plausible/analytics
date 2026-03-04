defmodule PlausibleWeb.PlainController do
  use PlausibleWeb, :controller

  alias Plausible.PlainCustomerCards

  def customer_cards(conn, params) do
    token = Application.get_env(:plausible, :plain)[:token]
    auth = get_req_header(conn, "authorization") |> List.first()

    if Plug.Crypto.secure_compare(auth || "", "Bearer #{token}") do
      email = get_in(params, ["customer", "email"])
      card_keys = Map.get(params, "cardKeys", ["customer-details"])

      cards =
        case PlainCustomerCards.get_customer_data(email) do
          {:ok, details} ->
            card = PlainCustomerCards.build_card(details)
            Enum.map(card_keys, fn _key -> card end)

          {:error, _} ->
            Enum.map(card_keys, fn key ->
              %{
                key: key,
                timeToLiveSeconds: 60,
                components: [
                  %{
                    componentText: %{
                      text: "Customer not found",
                      textSize: "M",
                      textColor: "MUTED"
                    }
                  }
                ]
              }
            end)
        end

      json(conn, %{cards: cards})
    else
      conn |> put_status(401) |> json(%{error: "Unauthorized"})
    end
  end
end
