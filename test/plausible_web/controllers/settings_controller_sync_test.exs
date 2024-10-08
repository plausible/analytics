defmodule PlausibleWeb.SettingsControllerSyncTest do
  use PlausibleWeb.ConnCase
  use Bamboo.Test
  use Plausible.Repo

  alias Plausible.Auth.User

  describe "PUT /settings/email" do
    setup [:create_user, :log_in]

    @tag :ce_build_only
    test "updates email but DOES NOT force reverification when feature disabled", %{
      conn: conn,
      user: user
    } do
      patch_env(:selfhost, enable_email_verification: false)

      password = "very-long-very-secret-123"

      user
      |> User.set_password(password)
      |> Repo.update!()

      assert user.email_verified

      conn =
        post(conn, Routes.settings_path(conn, :update_email), %{
          "user" => %{"email" => "new" <> user.email, "password" => password}
        })

      assert redirected_to(conn, 302) ==
               Routes.settings_path(conn, :security) <> "#update-email"

      updated_user = Repo.reload!(user)

      assert updated_user.email == "new" <> user.email
      assert updated_user.previous_email == user.email
      assert updated_user.email_verified

      assert_no_emails_delivered()
    end
  end
end
