defmodule PlausibleWeb.Api.CustomerSupport.UserControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible
  use Plausible.Repo

  on_ee do
    @approval %{"conversation" => "1", "code" => "ABCD", "approved_by" => "marko"}

    setup %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:*"])

      customer = insert(:user, totp_enabled: true, totp_secret: "secret", totp_token: "token")

      {:ok,
       conn: put_req_header(conn, "authorization", "Bearer #{api_key.key}"),
       customer: customer,
       automation: automation}
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

    describe "login email" do
      test "changes the user's email", %{conn: conn, customer: customer} do
        conn =
          post(conn, "/api/cs/v1/users/#{customer.id}/email", %{
            approval: @approval,
            email: customer.email,
            new_email: "new-login@example.com"
          })

        assert json_response(conn, 200)["result"]["email"] == "new-login@example.com"
        assert Repo.reload!(customer).email == "new-login@example.com"
        assert Repo.get_by(Plausible.Audit.Entry, name: "cs_api_user_email_changed")
      end

      test "refuses when the current email doesn't match", %{conn: conn, customer: customer} do
        conn =
          post(conn, "/api/cs/v1/users/#{customer.id}/email", %{
            approval: @approval,
            email: "someone-else@example.com",
            new_email: "new-login@example.com"
          })

        assert json_response(conn, 422)["error"] =~ "Email"
        assert Repo.reload!(customer).email == customer.email
      end

      test "refuses an email another user has", %{conn: conn, customer: customer} do
        other = new_user()

        conn =
          post(conn, "/api/cs/v1/users/#{customer.id}/email", %{
            approval: @approval,
            email: customer.email,
            new_email: other.email
          })

        assert json_response(conn, 422)
        assert Repo.reload!(customer).email == customer.email
      end
    end

    describe "delete user" do
      test "deletes a user with no subscription", %{conn: conn} do
        user = new_user()

        conn =
          post(conn, "/api/cs/v1/users/#{user.id}/delete", %{
            approval: @approval,
            email: user.email
          })

        assert json_response(conn, 200)["result"]["deleted"]
        refute Repo.get(Plausible.Auth.User, user.id)
        assert Repo.get_by(Plausible.Audit.Entry, name: "cs_api_user_deleted")
      end

      test "refuses a user whose team has an active subscription", %{conn: conn} do
        user = new_user()
        subscribe_to_growth_plan(user)

        conn =
          post(conn, "/api/cs/v1/users/#{user.id}/delete", %{
            approval: @approval,
            email: user.email
          })

        assert json_response(conn, 422)["error"] =~ "subscription"
        assert Repo.get(Plausible.Auth.User, user.id)
      end

      test "refuses when the email doesn't match", %{conn: conn} do
        user = new_user()

        conn =
          post(conn, "/api/cs/v1/users/#{user.id}/delete", %{
            approval: @approval,
            email: "someone-else@example.com"
          })

        assert json_response(conn, 422)
        assert Repo.get(Plausible.Auth.User, user.id)
      end

      test "stops at 5 deletions in 24 hours", %{conn: conn, automation: automation} do
        for _ <- 1..5 do
          Repo.insert!(%Plausible.Audit.Entry{
            name: "cs_api_site_deleted",
            entity: "Plausible.Site",
            entity_id: "1",
            user_id: automation.id,
            team_id: 0,
            actor_type: :user,
            datetime: NaiveDateTime.utc_now()
          })
        end

        user = new_user()

        conn =
          post(conn, "/api/cs/v1/users/#{user.id}/delete", %{
            approval: @approval,
            email: user.email
          })

        assert json_response(conn, 429)
        assert Repo.get(Plausible.Auth.User, user.id)
      end
    end
  end
end
