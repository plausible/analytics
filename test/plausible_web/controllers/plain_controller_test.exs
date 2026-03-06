defmodule PlausibleWeb.PlainControllerTest do
  use PlausibleWeb.ConnCase, async: true

  @moduletag :ee_only

  on_ee do
    @token Application.compile_env(:plausible, :plain)[:customer_card_token]

    defp auth_header(conn) do
      put_req_header(conn, "authorization", "Bearer #{@token}")
    end

    describe "customer_cards/2" do
      test "returns customer card for known user", %{conn: conn} do
        user = insert(:user, email: "plain.ctrl@example.com")

        body = %{
          cardKeys: ["customer-details"],
          customer: %{id: "c_123", email: user.email, externalId: nil},
          thread: %{id: "t_123", externalId: nil}
        }

        conn = conn |> auth_header() |> post("/plain/customer-cards", body)

        assert %{"cards" => [card]} = json_response(conn, 200)
        assert card["key"] == "customer-details"
        assert is_list(card["components"])
      end

      test "returns not found card for unknown user", %{conn: conn} do
        body = %{
          cardKeys: ["customer-details"],
          customer: %{id: "c_456", email: "nobody@example.com", externalId: nil},
          thread: %{id: "t_456", externalId: nil}
        }

        conn = conn |> auth_header() |> post("/plain/customer-cards", body)

        assert %{"cards" => [card]} = json_response(conn, 200)
        assert card["key"] == "customer-details"

        texts =
          card["components"]
          |> Enum.flat_map(fn
            %{"componentText" => %{"text" => t}} -> [t]
            _ -> []
          end)

        assert "Customer not found" in texts
      end

      test "returns 401 when authorization header is missing", %{conn: conn} do
        body = %{cardKeys: ["customer-details"], customer: %{email: "test@example.com"}}
        conn = post(conn, "/plain/customer-cards", body)
        assert json_response(conn, 401)
      end

      test "returns 401 when authorization token is invalid", %{conn: conn} do
        body = %{cardKeys: ["customer-details"], customer: %{email: "test@example.com"}}

        conn =
          conn
          |> put_req_header("authorization", "Bearer wrong-token")
          |> post("/plain/customer-cards", body)

        assert json_response(conn, 401)
      end
    end
  end
end
