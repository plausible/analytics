defmodule PlausibleWeb.AuthControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Bamboo.Test
  use Plausible.Teams.Test
  use Plausible.Repo

  import Plausible.Test.Support.HTML
  import Mox

  require Logger
  require Plausible.Billing.Subscription.Status

  alias Plausible.Auth
  alias Plausible.Auth.User
  alias Plausible.Billing.Subscription

  setup {PlausibleWeb.FirstLaunchPlug.Test, :skip}
  setup [:verify_on_exit!]

  describe "GET /register" do
    test "shows the register form", %{conn: conn} do
      conn = get(conn, "/register")

      assert html_response(conn, 200) =~ "Enter your details"
    end
  end

  describe "POST /login (register_action = register_form)" do
    test "registering sends an activation link", %{conn: conn} do
      Repo.insert!(
        User.new(%{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret-and-very-long-123",
          password_confirmation: "very-secret-and-very-long-123"
        })
      )

      post(conn, "/login",
        user: %{
          email: "user@example.com",
          password: "very-secret-and-very-long-123",
          register_action: "register_form"
        }
      )

      assert_delivered_email_matches(%{to: [{_, user_email}], subject: subject})
      assert user_email == "user@example.com"
      assert subject =~ "is your Plausible email verification code"
    end

    test "user is redirected to activate page after registration", %{conn: conn} do
      Repo.insert!(
        User.new(%{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret-and-very-long-123",
          password_confirmation: "very-secret-and-very-long-123"
        })
      )

      conn =
        post(conn, "/login",
          user: %{
            email: "user@example.com",
            password: "very-secret-and-very-long-123",
            register_action: "register_form"
          }
        )

      assert redirected_to(conn, 302) == "/activate?flow=register"
    end

    test "logs the user in", %{conn: conn} do
      user =
        Repo.insert!(
          User.new(%{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret-and-very-long-123",
            password_confirmation: "very-secret-and-very-long-123"
          })
        )

      conn =
        post(conn, "/login",
          user: %{
            email: "user@example.com",
            password: "very-secret-and-very-long-123",
            register_action: "register_form"
          }
        )

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn, :user_token) == token
    end
  end

  describe "GET /register/invitations/:invitation_id" do
    test "shows the register form", %{conn: conn} do
      inviter = new_user()
      site = new_site(owner: inviter)

      invitation = invite_guest(site, "user@email.co", role: :editor, inviter: inviter)

      conn = get(conn, "/register/invitation/#{invitation.invitation_id}")

      assert html_response(conn, 200) =~ "Enter your details"
    end
  end

  describe "POST /login (register_action = register_from_invitation_form)" do
    setup do
      inviter = new_user()
      site = new_site(owner: inviter)

      invitation = invite_guest(site, "user@email.co", role: :editor, inviter: inviter)

      user =
        Repo.insert!(
          User.new(%{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret-and-very-long-123",
            password_confirmation: "very-secret-and-very-long-123"
          })
        )

      {:ok, %{site: site, invitation: invitation, user: user}}
    end

    test "registering sends an activation link", %{conn: conn} do
      post(conn, "/login",
        user: %{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret-and-very-long-123",
          password_confirmation: "very-secret-and-very-long-123",
          register_action: "register_from_invitation_form"
        }
      )

      assert_delivered_email_matches(%{to: [{_, user_email}], subject: subject})
      assert user_email == "user@example.com"
      assert subject =~ "is your Plausible email verification code"
    end

    test "user is redirected to activate page after registration", %{conn: conn} do
      conn =
        post(conn, "/login",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret-and-very-long-123",
            password_confirmation: "very-secret-and-very-long-123",
            register_action: "register_from_invitation_form"
          }
        )

      assert redirected_to(conn, 302) == "/activate?flow=invitation"
    end

    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, "/login",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret-and-very-long-123",
            password_confirmation: "very-secret-and-very-long-123",
            register_action: "register_from_invitation_form"
          }
        )

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn, :user_token) == token
    end
  end

  describe "GET /activate" do
    setup [:create_user, :log_in]

    test "if user does not have a code: prompts user to request activation code", %{conn: conn} do
      conn = get(conn, "/activate")

      assert html_response(conn, 200) =~ "Request activation code"
    end

    test "if user does have a code: prompts user to enter the activation code from their email",
         %{conn: conn} do
      conn =
        post(conn, "/activate/request-code")
        |> get("/activate")

      assert html_response(conn, 200) =~ "Please enter the 4-digit code we sent to"
    end
  end

  describe "POST /activate/request-code" do
    setup [:create_user, :log_in]

    test "generates an activation pin for user account", %{conn: conn, user: user} do
      post(conn, "/activate/request-code")

      assert code = Repo.get_by(Auth.EmailActivationCode, user_id: user.id)

      assert code.user_id == user.id
      refute Plausible.Auth.EmailVerification.expired?(code)
    end

    test "regenerates an activation pin even if there's one already", %{conn: conn, user: user} do
      five_minutes_ago =
        NaiveDateTime.utc_now()
        |> Timex.shift(minutes: -5)
        |> NaiveDateTime.truncate(:second)

      {:ok, verification} = Auth.EmailVerification.issue_code(user, five_minutes_ago)

      post(conn, "/activate/request-code")

      assert new_verification = Repo.get_by(Auth.EmailActivationCode, user_id: user.id)

      assert verification.id == new_verification.id
      assert verification.user_id == new_verification.user_id
      # this actually has a chance to fail 1 in 8999 runs
      # but at the same time it's good to have a confirmation
      # that it indeed generates a new code
      if verification.code == new_verification.code do
        Logger.warning(
          "Congratulations! You you have hit 1 in 8999 chance of the same " <>
            "email verification code repeating twice in a row!"
        )
      end

      assert NaiveDateTime.compare(verification.issued_at, new_verification.issued_at) == :lt
    end

    test "sends activation email to user", %{conn: conn, user: user} do
      post(conn, "/activate/request-code")

      assert_delivered_email_matches(%{to: [{_, user_email}], subject: subject})
      assert user_email == user.email
      assert subject =~ "is your Plausible email verification code"
    end

    test "redirects user to /activate", %{conn: conn} do
      conn = post(conn, "/activate/request-code")

      assert redirected_to(conn, 302) == "/activate"
    end
  end

  describe "POST /activate" do
    setup [:create_user, :log_in]

    test "with wrong pin - reloads the form with error", %{conn: conn} do
      conn = post(conn, "/activate", %{code: "1234"})

      assert html_response(conn, 200) =~ "Incorrect activation code"
    end

    test "with expired pin - reloads the form with error", %{conn: conn, user: user} do
      one_day_ago =
        NaiveDateTime.utc_now()
        |> Timex.shift(days: -1)
        |> NaiveDateTime.truncate(:second)

      {:ok, verification} = Auth.EmailVerification.issue_code(user, one_day_ago)

      conn = post(conn, "/activate", %{code: verification.code})

      assert html_response(conn, 200) =~ "Code is expired, please request another one"
    end

    test "marks the user account as active", %{conn: conn, user: user} do
      Repo.update!(Plausible.Auth.User.changeset(user, %{email_verified: false}))
      post(conn, "/activate/request-code")

      verification = Repo.get_by!(Auth.EmailActivationCode, user_id: user.id)

      conn = post(conn, "/activate", %{code: verification.code})
      user = Repo.get_by(Plausible.Auth.User, id: user.id)

      assert user.email_verified
      assert redirected_to(conn) == "/sites/new?flow="
    end

    test "redirects to /sites if user has invitation", %{conn: conn, user: user} do
      owner = new_user()
      site = new_site(owner: owner)
      invite_guest(site, user, role: :viewer, inviter: owner)

      Repo.update!(Plausible.Auth.User.changeset(user, %{email_verified: false}))

      post(conn, "/activate/request-code")

      verification = Repo.get_by!(Auth.EmailActivationCode, user_id: user.id)

      conn = post(conn, "/activate", %{code: verification.code})

      assert redirected_to(conn) == "/sites?flow="
    end

    test "removes used up verification code", %{conn: conn, user: user} do
      Repo.update!(Plausible.Auth.User.changeset(user, %{email_verified: false}))
      post(conn, "/activate/request-code")

      verification = Repo.get_by!(Auth.EmailActivationCode, user_id: user.id)

      post(conn, "/activate", %{code: verification.code})

      refute Repo.get_by(Auth.EmailActivationCode, user_id: user.id)
    end
  end

  describe "GET /login_form" do
    test "shows the login form", %{conn: conn} do
      conn = get(conn, "/login")
      assert html_response(conn, 200) =~ "Enter your account credentials"
    end

    test "renders `return_to` query param as hidden input", %{conn: conn} do
      conn = get(conn, "/login?return_to=/dummy.site")

      [input_value] =
        conn
        |> html_response(200)
        |> Floki.parse_document!()
        |> Floki.attribute("input[name=return_to]", "value")

      assert input_value == "/dummy.site"
    end
  end

  describe "POST /login" do
    test "valid email and password - logs the user in", %{conn: conn} do
      user = insert(:user, password: "password")

      conn = post(conn, "/login", email: user.email, password: "password")

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn, :user_token) == token
      assert redirected_to(conn) == "/sites"
    end

    test "valid email and password with return_to set - redirects properly", %{conn: conn} do
      user = insert(:user, password: "password")

      conn =
        post(conn, "/login",
          email: user.email,
          password: "password",
          return_to: Routes.settings_path(conn, :index)
        )

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :index)
    end

    test "valid email and password with 2FA enabled - sets 2FA session and redirects", %{
      conn: conn
    } do
      user = insert(:user, password: "password")

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = post(conn, "/login", email: user.email, password: "password")

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :verify_2fa_form)

      assert fetch_cookies(conn).cookies["session_2fa"].current_2fa_user_id == user.id
      refute get_session(conn)["user_token"]
    end

    test "valid email and password with 2FA enabled and remember 2FA cookie set - logs the user in",
         %{conn: conn} do
      user = insert(:user, password: "password")

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = set_remember_2fa_cookie(conn, user)

      conn = post(conn, "/login", email: user.email, password: "password")

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert conn.resp_cookies["session_2fa"].max_age == 0
      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn, :user_token) == token
    end

    test "valid email and password with 2FA enabled and rogue remember 2FA cookie set - logs the user in",
         %{conn: conn} do
      user = insert(:user, password: "password")

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      another_user = insert(:user)
      conn = set_remember_2fa_cookie(conn, another_user)

      conn = post(conn, "/login", email: user.email, password: "password")

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :verify_2fa_form)

      assert fetch_cookies(conn).cookies["session_2fa"].current_2fa_user_id == user.id
      refute get_session(conn, :user_token)
    end

    test "email does not exist - renders login form again", %{conn: conn} do
      conn = post(conn, "/login", email: "user@example.com", password: "password")

      assert get_session(conn, :user_token) == nil
      assert html_response(conn, 200) =~ "Enter your account credentials"
    end

    test "bad password - renders login form again", %{conn: conn} do
      user = insert(:user, password: "password")
      conn = post(conn, "/login", email: user.email, password: "wrong")

      assert get_session(conn, :user_token) == nil
      assert html_response(conn, 200) =~ "Enter your account credentials"
    end

    test "limits login attempts to 5 per minute" do
      user = insert(:user, password: "password")

      conn = put_req_header(build_conn(), "x-forwarded-for", "1.2.3.5")

      response =
        eventually(
          fn ->
            Enum.each(1..5, fn _ ->
              post(conn, "/login", email: user.email, password: "wrong")
            end)

            conn = post(conn, "/login", email: user.email, password: "wrong")

            {conn.status == 429, conn}
          end,
          500
        )

      assert html_response(response, 429) =~ "Too many login attempts"
    end
  end

  describe "GET /password/request-reset" do
    test "renders the form", %{conn: conn} do
      conn = get(conn, "/password/request-reset")
      assert html_response(conn, 200) =~ "Enter your email so we can send a password reset link"
    end
  end

  describe "POST /password/request-reset" do
    test "email is empty - renders form with error", %{conn: conn} do
      conn = post(conn, "/password/request-reset", %{email: ""})

      assert html_response(conn, 200) =~ "Enter your email so we can send a password reset link"
    end

    test "email is present and exists - sends password reset email", %{conn: conn} do
      mock_captcha_success()
      user = insert(:user)
      conn = post(conn, "/password/request-reset", %{email: user.email})

      assert html_response(conn, 200) =~ "Success!"
      assert_email_delivered_with(subject: "Plausible password reset")
    end

    test "renders captcha errors in case of captcha input verification failure", %{conn: conn} do
      mock_captcha_failure()
      user = insert(:user)
      conn = post(conn, "/password/request-reset", %{email: user.email})

      assert html_response(conn, 200) =~ "Please complete the captcha"
    end
  end

  describe "GET /password/reset" do
    test "with valid token - shows form", %{conn: conn} do
      user = insert(:user)
      token = Plausible.Auth.Token.sign_password_reset(user.email)
      conn = get(conn, "/password/reset", %{token: token})

      assert html_response(conn, 200) =~ "Reset your password"
    end

    test "with invalid token - shows error page", %{conn: conn} do
      conn = get(conn, "/password/reset", %{token: "blabla"})

      assert html_response(conn, 401) =~ "Your token is invalid"
    end

    test "without token - shows error page", %{conn: conn} do
      conn = get(conn, "/password/reset", %{})

      assert html_response(conn, 401) =~ "Your token is invalid"
    end
  end

  describe "POST /password/reset" do
    test "redirects the user to login and shows success message", %{conn: conn} do
      conn = post(conn, "/password/reset", %{})

      assert location = "/login" = redirected_to(conn, 302)

      # cookie state is as expected for logged out user
      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age == 0
      assert get_session(conn, :user_token) == nil

      {:ok, %{conn: conn}} = PlausibleWeb.FirstLaunchPlug.Test.skip(%{conn: recycle(conn)})
      conn = get(conn, location)
      assert html_response(conn, 200) =~ "Password updated successfully"
    end
  end

  describe "GET /logout" do
    setup [:create_user, :log_in]

    test "redirects the user to root", %{conn: conn} do
      conn = get(conn, "/logout")

      assert location = "/" = redirected_to(conn, 302)

      # cookie state is as expected for logged out user
      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age == 0
      assert get_session(conn, :user_token) == nil

      {:ok, %{conn: conn}} = PlausibleWeb.FirstLaunchPlug.Test.skip(%{conn: recycle(conn)})
      conn = get(conn, location)
      assert html_response(conn, 200) =~ "Welcome to Plausible!"
    end

    test "redirects user to `redirect` param when provided", %{conn: conn} do
      conn = get(conn, "/logout", %{redirect: "/docs"})

      assert redirected_to(conn, 302) == "/docs"
    end
  end

  describe "DELETE /me" do
    setup [:create_user, :log_in, :create_site]
    use Plausible.Repo

    test "deletes the user", %{conn: conn, user: user, site: site} do
      Repo.insert_all("intro_emails", [
        %{
          user_id: user.id,
          timestamp: NaiveDateTime.utc_now()
        }
      ])

      Repo.insert_all("feedback_emails", [
        %{
          user_id: user.id,
          timestamp: NaiveDateTime.utc_now()
        }
      ])

      Repo.insert_all("create_site_emails", [
        %{
          user_id: user.id,
          timestamp: NaiveDateTime.utc_now()
        }
      ])

      Repo.insert_all("check_stats_emails", [
        %{
          user_id: user.id,
          timestamp: NaiveDateTime.utc_now()
        }
      ])

      Repo.insert_all("sent_renewal_notifications", [
        %{
          user_id: user.id,
          timestamp: NaiveDateTime.utc_now()
        }
      ])

      insert(:google_auth, site: site, user: user)
      subscribe_to_growth_plan(user, status: Subscription.Status.deleted())
      subscribe_to_growth_plan(user, status: Subscription.Status.active())
      subscribe_to_enterprise_plan(user, site_limit: 1, subscription?: false)

      {:ok, team} = Plausible.Teams.get_or_create(user)

      conn = delete(conn, "/me")
      assert redirected_to(conn) == "/"
      assert Repo.reload(site) == nil
      assert Repo.reload(user) == nil
      assert Repo.all(Plausible.Billing.Subscription) == []
      assert Repo.all(Plausible.Billing.EnterprisePlan) == []
      refute Repo.get(Plausible.Teams.Team, team.id)
    end

    test "deletes sites that the user owns", %{conn: conn, user: user, site: owner_site} do
      viewer_site = new_site()
      add_guest(viewer_site, user: user, role: :viewer)

      delete(conn, "/me")

      assert Repo.get(Plausible.Site, viewer_site.id)
      refute Repo.get(Plausible.Site, owner_site.id)
    end

    test "refuses to delete user when an only owner of a setup team", %{
      conn: conn,
      user: user,
      site: site
    } do
      Plausible.Teams.complete_setup(site.team)

      conn = delete(conn, "/me")

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :danger_zone)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You can't delete your account when you are the only owner on a team"

      assert Repo.reload(user)
    end

    test "refuses to delete user when an only owner of multiple setup teams", %{
      conn: conn,
      user: user,
      site: site
    } do
      Plausible.Teams.complete_setup(site.team)

      another_owner = new_user()
      another_site = new_site(owner: another_owner)
      add_member(another_site.team, user: user, role: :owner)
      Repo.delete!(another_owner)

      conn = delete(conn, "/me")

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :danger_zone)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You can't delete your account when you are the only owner on a team"

      assert Repo.reload(user)
    end

    test "context > team is autodeleted - personal segment is also deleted", %{
      conn: conn,
      user: user,
      site: owner_site
    } do
      segment =
        insert(:segment,
          type: :personal,
          owner: user,
          site: owner_site,
          name: "personal segment"
        )

      delete(conn, "/me")

      refute Repo.reload(segment)
    end

    test "context > team is autodeleted - site segment is also deleted", %{
      conn: conn,
      user: user,
      site: owner_site
    } do
      segment =
        insert(:segment,
          type: :site,
          owner: user,
          site: owner_site,
          name: "site segment"
        )

      delete(conn, "/me")

      refute Repo.reload(segment)
    end

    test "context > team is not autodeleted - personal segment is deleted", %{
      conn: conn,
      user: user
    } do
      another_owner = new_user()
      another_site = new_site(owner: another_owner)
      add_member(another_site.team, user: user, role: :admin)

      segment =
        insert(:segment,
          type: :personal,
          owner: user,
          site: another_site,
          name: "personal segment"
        )

      delete(conn, "/me")

      refute Repo.reload(segment)
    end

    test "context > team is not autodeleted - site segment is kept with owner=null", %{
      conn: conn,
      user: user
    } do
      another_owner = new_user()
      another_site = new_site(owner: another_owner)
      add_member(another_site.team, user: user, role: :admin)

      segment =
        insert(:segment,
          type: :site,
          owner: user,
          site: another_site,
          name: "site segment"
        )

      delete(conn, "/me")

      assert Repo.reload(segment).owner_id == nil
    end

    test "allows to delete user when not the only owner of a setup team", %{
      conn: conn,
      user: user
    } do
      another_owner = new_user()
      another_site = new_site(owner: another_owner)
      add_member(another_site.team, user: user, role: :owner)

      delete(conn, "/me")

      refute Repo.reload(user)
    end
  end

  describe "GET /auth/google/callback" do
    test "shows error and redirects back to settings when authentication fails", %{conn: conn} do
      site = insert(:site)
      callback_params = %{"error" => "access_denied", "state" => "[#{site.id},\"import\"]"}
      conn = get(conn, Routes.auth_path(conn, :google_auth_callback), callback_params)

      assert redirected_to(conn, 302) ==
               Routes.site_path(conn, :settings_imports_exports, site.domain)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "unable to authenticate your Google Analytics"
    end
  end

  describe "POST /2fa/setup/initiate" do
    setup [:create_user, :log_in]

    test "initiates setup rendering QR and human friendly versions of secret", %{
      conn: conn,
      user: user
    } do
      conn = post(conn, Routes.auth_path(conn, :initiate_2fa_setup))

      secret = Base.encode32(Repo.reload!(user).totp_secret)

      assert html = html_response(conn, 200)

      assert element_exists?(html, "svg")
      assert html =~ secret
    end

    test "redirects back to settings if 2FA is already setup", %{conn: conn, user: user} do
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = post(conn, Routes.auth_path(conn, :initiate_2fa_setup))

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :security) <> "#update-2fa"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Two-Factor Authentication is already setup"
    end
  end

  describe "GET /2fa/setup/verify" do
    setup [:create_user, :log_in]

    test "renders form when 2FA setup is initiated", %{conn: conn, user: user} do
      {:ok, _, _} = Auth.TOTP.initiate(user)

      conn = get(conn, Routes.auth_path(conn, :verify_2fa_setup))

      assert html = html_response(conn, 200)

      assert text_of_attr(html, "form#verify-2fa-form", "action") ==
               Routes.auth_path(conn, :verify_2fa_setup)

      assert element_exists?(html, "input[name=code]")

      assert element_exists?(
               html,
               ~s|a[data-method="post"][data-to="#{Routes.auth_path(conn, :initiate_2fa_setup)}"|
             )
    end

    test "redirects back to settings if 2FA not initiated", %{conn: conn} do
      conn = get(conn, Routes.auth_path(conn, :verify_2fa_setup))

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :security) <> "#update-2fa"
    end
  end

  describe "POST /2fa/setup/verify" do
    setup [:create_user, :log_in]

    test "enables 2FA and renders recovery codes when valid code provided", %{
      conn: conn,
      user: user
    } do
      {:ok, user, _} = Auth.TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)

      conn = post(conn, Routes.auth_path(conn, :verify_2fa_setup), %{code: code})

      assert html = html_response(conn, 200)

      assert list = [_ | _] = find(html, "#recovery-codes-list > *")
      assert length(list) == 10

      assert user |> Repo.reload!() |> Auth.TOTP.enabled?()
    end

    test "renders error on invalid code provided", %{conn: conn, user: user} do
      {:ok, _, _} = Auth.TOTP.initiate(user)

      conn = post(conn, Routes.auth_path(conn, :verify_2fa_setup), %{code: "invalid"})

      assert html_response(conn, 200)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "The provided code is invalid."
    end

    test "redirects to settings when 2FA is not initiated", %{conn: conn} do
      conn = post(conn, Routes.auth_path(conn, :verify_2fa_setup), %{code: "123123"})

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :security) <> "#update-2fa"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Please enable Two-Factor Authentication"
    end
  end

  describe "POST /2fa/disable" do
    setup [:create_user, :log_in]

    test "disables 2FA when valid password provided", %{conn: conn, user: user} do
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = post(conn, Routes.auth_path(conn, :disable_2fa), %{password: "password"})

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :security) <> "#update-2fa"

      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~
               "Two-Factor Authentication is disabled"

      refute user |> Repo.reload!() |> Auth.TOTP.enabled?()
    end

    test "renders error when invalid password provided", %{conn: conn, user: user} do
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = post(conn, Routes.auth_path(conn, :disable_2fa), %{password: "invalid"})

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :security) <> "#update-2fa"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Incorrect password provided"
    end
  end

  describe "POST /2fa/recovery_codes" do
    setup [:create_user, :log_in]

    test "generates new recovery codes when valid password provided", %{conn: conn, user: user} do
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn =
        post(conn, Routes.auth_path(conn, :generate_2fa_recovery_codes), %{password: "password"})

      assert html = html_response(conn, 200)

      assert list = [_ | _] = find(html, "#recovery-codes-list > *")
      assert length(list) == 10
    end

    test "renders error when invalid password provided", %{conn: conn, user: user} do
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn =
        post(conn, Routes.auth_path(conn, :generate_2fa_recovery_codes), %{password: "invalid"})

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :security) <> "#update-2fa"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Incorrect password provided"
    end

    test "renders error when 2FA is not enabled", %{conn: conn} do
      conn =
        post(conn, Routes.auth_path(conn, :generate_2fa_recovery_codes), %{password: "password"})

      assert redirected_to(conn, 302) == Routes.settings_path(conn, :security) <> "#update-2fa"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Please enable Two-Factor Authentication"
    end
  end

  describe "GET /2fa/verify" do
    test "renders verification form when 2FA session present", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      conn =
        get(
          conn,
          Routes.auth_path(conn, :verify_2fa_form, return_to: Routes.settings_path(conn, :index))
        )

      assert html = html_response(conn, 200)

      assert text_of_attr(html, "form", "action") ==
               Routes.auth_path(conn, :verify_2fa, return_to: Routes.settings_path(conn, :index))

      assert element_exists?(html, "input[name=code]")

      assert element_exists?(html, "input[name=remember_2fa]")

      assert text_of_attr(html, "input[name=return_to]", "value") ==
               Routes.settings_path(conn, :index)

      assert element_exists?(
               html,
               "a[href='#{Routes.auth_path(conn, :verify_2fa_recovery_code_form)}']"
             )
    end

    test "redirects to login when cookie not found", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = get(conn, Routes.auth_path(conn, :verify_2fa_form))

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login_form)
    end

    test "redirects to login when 2FA not enabled", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      {:ok, _} = Auth.TOTP.disable(user, "password")

      conn = get(conn, Routes.auth_path(conn, :verify_2fa_form))

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login_form)
    end
  end

  describe "POST /2fa/verify" do
    test "redirects to sites when code verification succeeds", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      code = NimbleTOTP.verification_code(user.totp_secret)

      conn = post(conn, Routes.auth_path(conn, :verify_2fa), %{code: code})

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn)["user_token"] == token
      # 2FA session terminated
      assert conn.resp_cookies["session_2fa"].max_age == 0
      # Remember cookie unset
      assert conn.resp_cookies["remember_2fa"].max_age == 0
    end

    test "redirects to return_to when set", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      code = NimbleTOTP.verification_code(user.totp_secret)

      conn =
        post(conn, Routes.auth_path(conn, :verify_2fa), %{code: code, return_to: "/dummy.site"})

      assert redirected_to(conn, 302) == "/dummy.site"
    end

    test "sets remember cookie when device trusted", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      code = NimbleTOTP.verification_code(user.totp_secret)

      conn = post(conn, Routes.auth_path(conn, :verify_2fa), %{code: code, remember_2fa: "true"})

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn)["user_token"] == token
      # 2FA session terminated
      assert conn.resp_cookies["session_2fa"].max_age == 0
      # Remember cookie set
      assert conn.resp_cookies["remember_2fa"].max_age > 0
    end

    test "overwrites rogue remember cookie when device trusted", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      another_user = insert(:user, totp_token: "different_token")
      conn = set_remember_2fa_cookie(conn, another_user)

      code = NimbleTOTP.verification_code(user.totp_secret)

      conn = post(conn, Routes.auth_path(conn, :verify_2fa), %{code: code, remember_2fa: "true"})

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn)["user_token"] == token
      # 2FA session terminated
      assert conn.resp_cookies["session_2fa"].max_age == 0
      # Remember cookie set
      assert conn.resp_cookies["remember_2fa"].max_age > 0
      assert fetch_cookies(conn).cookies["remember_2fa"] == user.totp_token
    end

    test "clears rogue remember cookie when device _not_ trusted", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      another_user = insert(:user, totp_token: "different_token")
      conn = set_remember_2fa_cookie(conn, another_user)

      code = NimbleTOTP.verification_code(user.totp_secret)

      conn = post(conn, Routes.auth_path(conn, :verify_2fa), %{code: code})

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn, :user_token) == token
      # 2FA session terminated
      assert conn.resp_cookies["session_2fa"].max_age == 0
      # Remember cookie cleared
      assert conn.resp_cookies["remember_2fa"].max_age == 0
    end

    test "returns error on invalid code", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      conn = post(conn, Routes.auth_path(conn, :verify_2fa), %{code: "invalid"})

      assert html_response(conn, 200)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "The provided code is invalid"
    end

    test "redirects to login when cookie not found", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      code = NimbleTOTP.verification_code(user.totp_secret)

      conn = post(conn, Routes.auth_path(conn, :verify_2fa, %{code: code}))

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login_form)
    end

    test "passes through when 2FA is disabled", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      code = NimbleTOTP.verification_code(user.totp_secret)

      {:ok, _} = Auth.TOTP.disable(user, "password")

      conn = post(conn, Routes.auth_path(conn, :verify_2fa), %{code: code})

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn)["user_token"] == token
      # 2FA session terminated
      assert conn.resp_cookies["session_2fa"].max_age == 0
    end

    test "limits verification attempts to 5 per minute", %{conn: conn} do
      user = insert(:user, email: "ratio#{Ecto.UUID.generate()}@example.com")

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn =
        conn
        |> login_with_cookie(user.email, "password")
        |> put_req_header("x-forwarded-for", "1.1.1.1")

      response =
        eventually(
          fn ->
            Enum.each(1..5, fn _ ->
              post(conn, Routes.auth_path(conn, :verify_2fa), %{code: "invalid"})
            end)

            conn = post(conn, Routes.auth_path(conn, :verify_2fa), %{code: "invalid"})

            {conn.status == 429, conn}
          end,
          500
        )

      assert get_session(response, :user_token) == nil
      # 2FA session terminated
      assert response.resp_cookies["session_2fa"].max_age == 0
      assert html_response(response, 429) =~ "Too many login attempts"
    end
  end

  describe "GET /2fa/use_recovery_code" do
    test "renders recovery verification form when 2FA session present", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      conn = get(conn, Routes.auth_path(conn, :verify_2fa_recovery_code_form))

      assert html = html_response(conn, 200)

      assert text_of_attr(html, "form", "action") ==
               Routes.auth_path(conn, :verify_2fa_recovery_code)

      assert element_exists?(html, "input[name=recovery_code]")

      assert element_exists?(html, "a[href='#{Routes.auth_path(conn, :verify_2fa_form)}']")
    end

    test "redirects to login when cookie not found", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = get(conn, Routes.auth_path(conn, :verify_2fa_recovery_code_form))

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login_form)
    end

    test "redirects to login when 2FA not enabled", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      {:ok, _} = Auth.TOTP.disable(user, "password")

      conn = get(conn, Routes.auth_path(conn, :verify_2fa_recovery_code_form))

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login_form)
    end
  end

  describe "POST /2fa/use_recovery_code" do
    test "redirects to sites when recovery code verification succeeds", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, %{recovery_codes: [recovery_code | _]}} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      conn =
        post(conn, Routes.auth_path(conn, :verify_2fa_recovery_code), %{
          recovery_code: recovery_code
        })

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn)["user_token"] == token
      # 2FA session terminated
      assert conn.resp_cookies["session_2fa"].max_age == 0
    end

    test "returns error on invalid recovery code", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      conn =
        post(conn, Routes.auth_path(conn, :verify_2fa_recovery_code), %{recovery_code: "invalid"})

      assert html_response(conn, 200)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "The provided recovery code is invalid"
    end

    test "redirects to login when cookie not found", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, _, %{recovery_codes: [recovery_code | _]}} = Auth.TOTP.enable(user, :skip_verify)

      conn =
        post(
          conn,
          Routes.auth_path(conn, :verify_2fa_recovery_code, %{recovery_code: recovery_code})
        )

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :login_form)
    end

    test "passes through when 2FA is disabled", %{conn: conn} do
      user = insert(:user)

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, %{recovery_codes: [recovery_code | _]}} = Auth.TOTP.enable(user, :skip_verify)

      conn = login_with_cookie(conn, user.email, "password")

      {:ok, _} = Auth.TOTP.disable(user, "password")

      conn =
        post(conn, Routes.auth_path(conn, :verify_2fa_recovery_code), %{
          recovery_code: recovery_code
        })

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)

      assert %{sessions: [%{token: token}]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert get_session(conn)["user_token"] == token
      # 2FA session terminated
      assert conn.resp_cookies["session_2fa"].max_age == 0
    end

    test "limits verification attempts to 5 per minute", %{conn: conn} do
      user = insert(:user, email: "ratio#{Ecto.UUID.generate()}@example.com")

      # enable 2FA
      {:ok, user, _} = Auth.TOTP.initiate(user)
      {:ok, user, _} = Auth.TOTP.enable(user, :skip_verify)

      conn =
        conn
        |> login_with_cookie(user.email, "password")
        |> put_req_header("x-forwarded-for", "1.2.3.4")

      response =
        eventually(
          fn ->
            Enum.each(1..5, fn _ ->
              post(conn, Routes.auth_path(conn, :verify_2fa_recovery_code), %{
                recovery_code: "invalid"
              })
            end)

            conn =
              post(conn, Routes.auth_path(conn, :verify_2fa_recovery_code), %{
                recovery_code: "invalid"
              })

            {conn.status == 429, conn}
          end,
          500
        )

      assert get_session(response, :user_token) == nil
      # 2FA session terminated
      assert response.resp_cookies["session_2fa"].max_age == 0
      assert html_response(response, 429) =~ "Too many login attempts"
    end
  end

  defp login_with_cookie(conn, email, password) do
    conn
    |> post(Routes.auth_path(conn, :login), %{
      email: email,
      password: password
    })
    |> recycle()
    |> Map.put(:secret_key_base, secret_key_base())
    |> Plug.Conn.put_req_header("x-forwarded-for", Plausible.TestUtils.random_ip())
  end

  defp set_remember_2fa_cookie(conn, user) do
    conn
    |> PlausibleWeb.TwoFactor.Session.maybe_set_remember_2fa(user, "true")
    |> recycle()
    |> Map.put(:secret_key_base, secret_key_base())
    |> Plug.Conn.put_req_header("x-forwarded-for", Plausible.TestUtils.random_ip())
  end

  defp mock_captcha_success() do
    mock_captcha(true)
  end

  defp mock_captcha_failure() do
    mock_captcha(false)
  end

  defp mock_captcha(success) do
    expect(
      Plausible.HTTPClient.Mock,
      :post,
      fn _, _, _ ->
        {:ok,
         %Finch.Response{
           status: 200,
           headers: [{"content-type", "application/json"}],
           body: %{"success" => success}
         }}
      end
    )
  end

  defp secret_key_base() do
    :plausible
    |> Application.fetch_env!(PlausibleWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
