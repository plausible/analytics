defmodule PlausibleWeb.Api.CustomerSupport.UserControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible
  use Plausible.Repo

  on_ee do
    @approval %{"conversation" => "1", "code" => "ABCD", "approved_by" => "marko"}

    setup %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:accounts:*"])

      customer = insert(:user, totp_enabled: true, totp_secret: "secret", totp_token: "token")

      {:ok,
       conn: put_req_header(conn, "authorization", "Bearer #{api_key.key}"), customer: customer}
    end

    test "turns off 2FA for the user and records it", %{conn: conn, customer: customer} do
      conn =
        post(conn, "/api/cs/v1/users/#{customer.id}/disable_2fa", %{
          approval: @approval,
          email: String.upcase(customer.email)
        })

      assert json_response(conn, 200)["result"]["totp_enabled"] == false

      customer = Repo.reload!(customer)
      refute customer.totp_enabled
      assert is_nil(customer.totp_secret)

      entry = Repo.get_by(Plausible.Audit.Entry, name: "cs_api_user_2fa_disabled")
      assert entry.entity_id == to_string(customer.id)
      assert entry.meta["approval"]["code"] == "ABCD"
    end

    test "refuses when the email doesn't match the user", %{conn: conn, customer: customer} do
      conn =
        post(conn, "/api/cs/v1/users/#{customer.id}/disable_2fa", %{
          approval: @approval,
          email: "someone-else@example.com"
        })

      assert json_response(conn, 422)["error"] =~ "Email"
      assert Repo.reload!(customer).totp_enabled
      refute Repo.get_by(Plausible.Audit.Entry, name: "cs_api_user_2fa_disabled")
    end

    test "refuses when 2FA isn't enabled", %{conn: conn} do
      user = new_user()

      conn =
        post(conn, "/api/cs/v1/users/#{user.id}/disable_2fa", %{
          approval: @approval,
          email: user.email
        })

      assert json_response(conn, 422)["error"] =~ "isn't enabled"
    end

    test "returns 404 for an unknown user", %{conn: conn} do
      conn =
        post(conn, "/api/cs/v1/users/0/disable_2fa", %{approval: @approval, email: "a@b.com"})

      assert json_response(conn, 404)
    end

    test "needs an approval", %{conn: conn, customer: customer} do
      conn = post(conn, "/api/cs/v1/users/#{customer.id}/disable_2fa", %{email: customer.email})

      assert json_response(conn, 400)["error"] =~ "approval"
      assert Repo.reload!(customer).totp_enabled
    end

    test "needs the cs:accounts scope", %{customer: customer} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:billing:*"])

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{api_key.key}")
        |> post("/api/cs/v1/users/#{customer.id}/disable_2fa", %{
          approval: @approval,
          email: customer.email
        })

      assert json_response(conn, 401)
      assert Repo.reload!(customer).totp_enabled
    end
  end
end
