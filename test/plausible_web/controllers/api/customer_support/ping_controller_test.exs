defmodule PlausibleWeb.Api.CustomerSupport.PingControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible

  on_ee do
    test "returns the key's user", %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:*"])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_key.key}")
        |> get("/api/cs/v1/ping")

      assert json_response(conn, 200) == %{
               "ok" => true,
               "user_id" => automation.id,
               "email" => automation.email
             }
    end

    test "refuses a key whose user isn't on the list", %{conn: conn} do
      user = new_user()
      api_key = insert(:api_key, user: user, scopes: ["cs:*"])

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_key.key}")
        |> get("/api/cs/v1/ping")

      assert json_response(conn, 401)
    end
  end
end
