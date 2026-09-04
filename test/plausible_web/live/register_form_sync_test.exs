defmodule PlausibleWeb.Live.RegisterFormSyncTest do
  use PlausibleWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias Plausible.Auth.User
  alias Plausible.Repo

  @strong_password "very-long-and-very-secret-123"

  setup do
    # A pre-existing user keeps the instance from being treated as a brand new
    # install, where creating the very first user is allowed and registration is
    # never disabled. Every test here depends on that.
    inviter = new_user()
    site = new_site(owner: inviter)
    invitation = invite_guest(site, build(:user).email, role: :editor, inviter: inviter)

    {:ok, invitation: invitation}
  end

  describe "DISABLE_REGISTRATION=invite_only" do
    setup do
      patch_disable_registration(:invite_only)
    end

    test "public /register is blocked on HTTP page load", %{conn: conn} do
      conn = get(conn, "/register")
      assert redirected_to(conn) == "/login"
    end

    test "register LiveView is disabled on invite only instance", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login", flash: flash}}} = live(conn, "/register")

      assert flash["error"] == "Registration is disabled on this instance"
    end

    test "register event over the LiveView socket cannot bypass invite_only via an invalid invitation",
         %{conn: conn} do
      mock_captcha_success()

      assert {:error, {:redirect, %{to: "/invitation-expired"}}} =
               live(conn, "/register/invitation/does-not-exist")
    end

    test "registration from a valid invitation still works", %{conn: conn, invitation: invitation} do
      mock_captcha_success()

      {:ok, lv, _html} = live(conn, "/register/invitation/#{invitation.invitation_id}")

      lv
      |> element("form")
      |> render_submit(%{"user" => %{"name" => "Mary Sue", "password" => @strong_password}})

      assert Repo.get_by(User, email: invitation.team_invitation.email)
    end
  end

  describe "DISABLE_REGISTRATION=true" do
    setup do
      patch_disable_registration(true)
    end

    test "register LiveView is disabled on fully disabled instance", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login", flash: flash}}} = live(conn, "/register")

      assert flash["error"] == "Registration is disabled on this instance"
    end

    test "register event from a valid invitation cannot bypass a fully disabled instance",
         %{conn: conn, invitation: invitation} do
      assert {:error, {:redirect, %{to: "/login", flash: flash}}} =
               live(conn, "/register/invitation/#{invitation.invitation_id}")

      assert flash["error"] == "Registration is disabled on this instance"
    end

    test "register event without a valid invitation cannot bypass a fully disabled instance",
         %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login", flash: flash}}} =
               live(conn, "/register/invitation/does-not-exist")

      assert flash["error"] == "Registration is disabled on this instance"
    end
  end

  describe "DISABLE_REGISTRATION=true with another session open" do
    setup do
      # We emulate a situation where another user has a LV session running when
      # the first user registers in the meantime.
      patch_disable_registration(false)
    end

    test "concluding register isn't allowed for ongoing session", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/register")

      patch_disable_registration(true)

      attacker_email = build(:user).email

      result =
        render_hook(lv, "register", %{
          "user" => %{
            "name" => "Attacker",
            "email" => attacker_email,
            "password" => @strong_password
          }
        })

      refute Repo.get_by(User, email: attacker_email)
      # flash seems to be serialized to cookie encoded format,
      # but it's confirmed to show the right notification
      assert {:error, {:redirect, %{to: "/login", flash: _}}} = result
    end

    test "concluding register from invitation isn't allowed for ongoing session", %{
      conn: conn,
      invitation: invitation
    } do
      {:ok, lv, _html} = live(conn, "/register/invitation/#{invitation.invitation_id}")

      patch_disable_registration(true)

      attacker_email = build(:user).email

      result =
        render_hook(lv, "register", %{
          "user" => %{
            "name" => "Attacker",
            "email" => attacker_email,
            "password" => @strong_password
          }
        })

      refute Repo.get_by(User, email: attacker_email)
      # flash seems to be serialized to cookie encoded format,
      # but it's confirmed to show the right notification
      assert {:error, {:redirect, %{to: "/login", flash: _}}} = result
    end
  end

  describe "DISABLE_REGISTRATION=invite_only with another session open" do
    setup do
      # We emulate a situation where another user has a LV session running when
      # the first user registers in the meantime.
      patch_disable_registration(false)
    end

    test "concluding register isn't allowed for ongoing session", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/register")

      patch_disable_registration(:invite_only)

      attacker_email = build(:user).email

      result =
        render_hook(lv, "register", %{
          "user" => %{
            "name" => "Attacker",
            "email" => attacker_email,
            "password" => @strong_password
          }
        })

      refute Repo.get_by(User, email: attacker_email)
      # flash seems to be serialized to cookie encoded format,
      # but it's confirmed to show the right notification
      assert {:error, {:redirect, %{to: "/login", flash: _}}} = result
    end

    test "concluding register from invitation is still allowed for ongoing session", %{
      conn: conn,
      invitation: invitation
    } do
      mock_captcha_success()
      {:ok, lv, _html} = live(conn, "/register/invitation/#{invitation.invitation_id}")

      patch_disable_registration(:invite_only)

      lv
      |> element("form")
      |> render_submit(%{"user" => %{"name" => "Mary Sue", "password" => @strong_password}})

      assert Repo.get_by(User, email: invitation.team_invitation.email)
    end
  end

  defp patch_disable_registration(value) do
    selfhost_config = Application.get_env(:plausible, :selfhost)
    patch_env(:selfhost, Keyword.put(selfhost_config, :disable_registration, value))
  end

  # Captcha is enabled in the test env, so make it pass. Without this a guard
  # regression would still be stopped by the captcha, and these tests would pass
  # for the wrong reason.
  defp mock_captcha_success do
    stub(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _body ->
      {:ok,
       %Finch.Response{
         status: 200,
         headers: [{"content-type", "application/json"}],
         body: %{"success" => true}
       }}
    end)
  end
end
