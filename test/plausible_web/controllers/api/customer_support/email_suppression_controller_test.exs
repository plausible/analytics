defmodule PlausibleWeb.Api.CustomerSupport.EmailSuppressionControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible

  on_ee do
    @approval %{"conversation" => "1", "code" => "ABCD", "approved_by" => "marko"}

    setup %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:emails:*"])

      {:ok, conn: put_req_header(conn, "authorization", "Bearer #{api_key.key}")}
    end

    test "reactivate returns 404 for an address that isn't suppressed", %{conn: conn} do
      conn =
        post(conn, "/api/cs/v1/email_suppressions/reactivate", %{
          approval: @approval,
          email: "nobody@example.com"
        })

      assert json_response(conn, 404)
    end

    test "reactivate needs an approval", %{conn: conn} do
      conn = post(conn, "/api/cs/v1/email_suppressions/reactivate", %{email: "a@example.com"})
      assert json_response(conn, 400)["error"] =~ "approval"
    end
  end
end
