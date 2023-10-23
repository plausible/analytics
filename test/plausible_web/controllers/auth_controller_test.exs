defmodule PlausibleWeb.AuthControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Bamboo.Test
  use Plausible.Repo

  import Plausible.Test.Support.HTML
  import Mox

  require Logger
  require Plausible.Billing.Subscription.Status

  alias Plausible.Auth
  alias Plausible.Auth.User
  alias Plausible.Billing.Subscription

  setup :verify_on_exit!

  @v3_plan_id "749355"
  @configured_enterprise_plan_paddle_plan_id "123"

  describe "GET /register" do
    test "shows the register form", %{conn: conn} do
      conn = get(conn, "/register")

      assert html_response(conn, 200) =~ "Enter your details"
    end
  end

  describe "POST /register" do
    test "registering sends an activation link", %{conn: conn} do
      Repo.insert!(
        User.new(%{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret-and-very-long-123",
          password_confirmation: "very-secret-and-very-long-123"
        })
      )

      post(conn, "/register",
        user: %{
          email: "user@example.com",
          password: "very-secret-and-very-long-123"
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
        post(conn, "/register",
          user: %{
            email: "user@example.com",
            password: "very-secret-and-very-long-123"
          }
        )

      assert redirected_to(conn, 302) == "/activate"
    end

    test "logs the user in", %{conn: conn} do
      Repo.insert!(
        User.new(%{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret-and-very-long-123",
          password_confirmation: "very-secret-and-very-long-123"
        })
      )

      conn =
        post(conn, "/register",
          user: %{
            email: "user@example.com",
            password: "very-secret-and-very-long-123"
          }
        )

      assert get_session(conn, :current_user_id)
    end
  end

  describe "GET /register/invitations/:invitation_id" do
    test "shows the register form", %{conn: conn} do
      inviter = insert(:user)
      site = insert(:site, members: [inviter])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: inviter,
          email: "user@email.co",
          role: :admin
        )

      conn = get(conn, "/register/invitation/#{invitation.invitation_id}")

      assert html_response(conn, 200) =~ "Enter your details"
    end
  end

  describe "POST /register/invitation/:invitation_id" do
    setup do
      inviter = insert(:user)
      site = insert(:site, members: [inviter])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: inviter,
          email: "user@email.co",
          role: :admin
        )

      Repo.insert!(
        User.new(%{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret-and-very-long-123",
          password_confirmation: "very-secret-and-very-long-123"
        })
      )

      {:ok, %{site: site, invitation: invitation}}
    end

    test "registering sends an activation link", %{conn: conn, invitation: invitation} do
      post(conn, "/register/invitation/#{invitation.invitation_id}",
        user: %{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret-and-very-long-123",
          password_confirmation: "very-secret-and-very-long-123"
        }
      )

      assert_delivered_email_matches(%{to: [{_, user_email}], subject: subject})
      assert user_email == "user@example.com"
      assert subject =~ "is your Plausible email verification code"
    end

    test "user is redirected to activate page after registration", %{
      conn: conn,
      invitation: invitation
    } do
      conn =
        post(conn, "/register/invitation/#{invitation.invitation_id}",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret-and-very-long-123",
            password_confirmation: "very-secret-and-very-long-123"
          }
        )

      assert redirected_to(conn, 302) == "/activate"
    end

    test "logs the user in", %{conn: conn, invitation: invitation} do
      conn =
        post(conn, "/register/invitation/#{invitation.invitation_id}",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret-and-very-long-123",
            password_confirmation: "very-secret-and-very-long-123"
          }
        )

      assert get_session(conn, :current_user_id)
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
      assert redirected_to(conn) == "/sites/new"
    end

    test "redirects to /sites if user has invitation", %{conn: conn, user: user} do
      site = insert(:site)
      insert(:invitation, inviter: build(:user), site: site, email: user.email)
      Repo.update!(Plausible.Auth.User.changeset(user, %{email_verified: false}))
      post(conn, "/activate/request-code")

      verification = Repo.get_by!(Auth.EmailActivationCode, user_id: user.id)

      conn = post(conn, "/activate", %{code: verification.code})

      assert redirected_to(conn) == "/sites"
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
      assert html_response(conn, 200) =~ "Enter your email and password"
    end
  end

  describe "POST /login" do
    test "valid email and password - logs the user in", %{conn: conn} do
      user = insert(:user, password: "password")

      conn = post(conn, "/login", email: user.email, password: "password")

      assert get_session(conn, :current_user_id) == user.id
      assert redirected_to(conn) == "/sites"
    end

    test "email does not exist - renders login form again", %{conn: conn} do
      conn = post(conn, "/login", email: "user@example.com", password: "password")

      assert get_session(conn, :current_user_id) == nil
      assert html_response(conn, 200) =~ "Enter your email and password"
    end

    test "bad password - renders login form again", %{conn: conn} do
      user = insert(:user, password: "password")
      conn = post(conn, "/login", email: user.email, password: "wrong")

      assert get_session(conn, :current_user_id) == nil
      assert html_response(conn, 200) =~ "Enter your email and password"
    end

    test "limits login attempts to 5 per minute" do
      user = insert(:user, password: "password")

      build_conn()
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> post("/login", email: user.email, password: "wrong")

      build_conn()
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> post("/login", email: user.email, password: "wrong")

      build_conn()
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> post("/login", email: user.email, password: "wrong")

      build_conn()
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> post("/login", email: user.email, password: "wrong")

      build_conn()
      |> put_req_header("x-forwarded-for", "1.1.1.1")
      |> post("/login", email: user.email, password: "wrong")

      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", "1.1.1.1")
        |> post("/login", email: user.email, password: "wrong")

      assert get_session(conn, :current_user_id) == nil
      assert html_response(conn, 429) =~ "Too many login attempts"
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

      conn = get(recycle(conn), location)
      assert html_response(conn, 200) =~ "Password updated successfully"
    end
  end

  describe "GET /settings" do
    setup [:create_user, :log_in]

    test "shows the form", %{conn: conn} do
      conn = get(conn, "/settings")
      assert resp = html_response(conn, 200)
      assert resp =~ "Change account name"
      assert resp =~ "Change email address"
    end

    test "shows subscription", %{conn: conn, user: user} do
      insert(:subscription, paddle_plan_id: "558018", user: user)
      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "10k pageviews"
      assert html_response(conn, 200) =~ "monthly billing"
    end

    test "shows yearly subscription", %{conn: conn, user: user} do
      insert(:subscription, paddle_plan_id: "590752", user: user)
      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "100k pageviews"
      assert html_response(conn, 200) =~ "yearly billing"
    end

    test "shows free subscription", %{conn: conn, user: user} do
      insert(:subscription, paddle_plan_id: "free_10k", user: user)
      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "10k pageviews"
      assert html_response(conn, 200) =~ "N/A billing"
    end

    test "shows enterprise plan subscription", %{conn: conn, user: user} do
      insert(:subscription, paddle_plan_id: "123", user: user)

      configure_enterprise_plan(user)

      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "20M pageviews"
      assert html_response(conn, 200) =~ "yearly billing"
    end

    test "shows current enterprise plan subscription when user has a new one to upgrade to", %{
      conn: conn,
      user: user
    } do
      insert(:subscription,
        paddle_plan_id: @configured_enterprise_plan_paddle_plan_id,
        user: user
      )

      insert(:enterprise_plan,
        paddle_plan_id: "1234",
        user: user,
        monthly_pageview_limit: 10_000_000,
        billing_interval: :yearly
      )

      configure_enterprise_plan(user)

      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "20M pageviews"
      assert html_response(conn, 200) =~ "yearly billing"
    end

    test "links to upgrade to a plan", %{conn: conn} do
      doc =
        get(conn, "/settings")
        |> html_response(200)

      upgrade_link_1 = find(doc, "#monthly-quota-box a")
      upgrade_link_2 = find(doc, "#upgrade-link-2")

      assert text(upgrade_link_1) == "Upgrade"
      assert text_of_attr(upgrade_link_1, "href") == Routes.billing_path(conn, :choose_plan)

      assert text(upgrade_link_2) == "Upgrade"
      assert text_of_attr(upgrade_link_2, "href") == Routes.billing_path(conn, :choose_plan)
    end

    test "links to change existing plan", %{
      conn: conn,
      user: user
    } do
      insert(:subscription, paddle_plan_id: @v3_plan_id, user: user)

      doc =
        get(conn, "/settings")
        |> html_response(200)

      refute element_exists?(doc, "#upgrade-link-2")
      assert doc =~ "Cancel my subscription"

      change_plan_link = find(doc, "#monthly-quota-box a")

      assert text(change_plan_link) == "Change plan"
      assert text_of_attr(change_plan_link, "href") == Routes.billing_path(conn, :choose_plan)
    end

    test "upgrade_to_enterprise_plan link does not show up when subscription is past_due", %{
      conn: conn,
      user: user
    } do
      configure_enterprise_plan(user)

      insert(:subscription,
        user: user,
        status: Subscription.Status.past_due(),
        paddle_plan_id: @configured_enterprise_plan_paddle_plan_id
      )

      doc =
        conn
        |> get(Routes.auth_path(conn, :user_settings))
        |> html_response(200)

      refute element_exists?(doc, "#upgrade-or-change-plan-link")
    end

    test "upgrade_to_enterprise_plan link does not show up when subscription is paused", %{
      conn: conn,
      user: user
    } do
      configure_enterprise_plan(user)

      insert(:subscription,
        user: user,
        status: Subscription.Status.paused(),
        paddle_plan_id: @configured_enterprise_plan_paddle_plan_id
      )

      doc =
        conn
        |> get(Routes.auth_path(conn, :user_settings))
        |> html_response(200)

      refute element_exists?(doc, "#upgrade-or-change-plan-link")
    end

    test "links to upgrade to enterprise plan",
         %{conn: conn, user: user} do
      configure_enterprise_plan(user)

      doc =
        get(conn, "/settings")
        |> html_response(200)

      upgrade_link_1 = find(doc, "#monthly-quota-box a")
      upgrade_link_2 = find(doc, "#upgrade-link-2")

      assert text(upgrade_link_1) == "Upgrade"

      assert text_of_attr(upgrade_link_1, "href") ==
               Routes.billing_path(conn, :upgrade_to_enterprise_plan)

      assert text(upgrade_link_2) == "Upgrade"

      assert text_of_attr(upgrade_link_2, "href") ==
               Routes.billing_path(conn, :upgrade_to_enterprise_plan)
    end

    test "links to change enterprise plan and cancel subscription",
         %{conn: conn, user: user} do
      insert(:subscription, paddle_plan_id: @v3_plan_id, user: user)

      configure_enterprise_plan(user)

      doc =
        get(conn, "/settings")
        |> html_response(200)

      refute element_exists?(doc, "#upgrade-link-2")
      assert doc =~ "Cancel my subscription"

      change_plan_link = find(doc, "#monthly-quota-box a")

      assert text(change_plan_link) == "Change plan"

      assert text_of_attr(change_plan_link, "href") ==
               Routes.billing_path(conn, :upgrade_to_enterprise_plan)
    end

    test "shows invoices for subscribed user", %{conn: conn, user: user} do
      insert(:subscription,
        paddle_plan_id: "558018",
        paddle_subscription_id: "redundant",
        user: user
      )

      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "Dec 24, 2020"
      assert html_response(conn, 200) =~ "€11.11"
      assert html_response(conn, 200) =~ "Nov 24, 2020"
      assert html_response(conn, 200) =~ "$22.00"
    end

    test "shows 'something went wrong' on failed invoice request'", %{conn: conn, user: user} do
      insert(:subscription,
        paddle_plan_id: "558018",
        paddle_subscription_id: "invalid_subscription_id",
        user: user
      )

      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "Invoices"
      assert html_response(conn, 200) =~ "Something went wrong"
    end

    test "does not show invoice section for a user with no subscription", %{conn: conn} do
      conn = get(conn, "/settings")
      refute html_response(conn, 200) =~ "Invoices"
    end

    test "does not show invoice section for a free subscription", %{conn: conn, user: user} do
      Plausible.Billing.Subscription.free(%{user_id: user.id, currency_code: "EUR"})
      |> Repo.insert!()

      conn = get(conn, "/settings")
      refute html_response(conn, 200) =~ "Invoices"
    end
  end

  describe "PUT /settings" do
    setup [:create_user, :log_in]

    test "updates user record", %{conn: conn, user: user} do
      put(conn, "/settings", %{"user" => %{"name" => "New name"}})

      user = Plausible.Repo.get(Plausible.Auth.User, user.id)
      assert user.name == "New name"
    end

    test "does not allow setting non-profile fields", %{conn: conn, user: user} do
      expiry_date = user.trial_expiry_date

      assert %Date{} = expiry_date

      put(conn, "/settings", %{
        "user" => %{"name" => "New name", "trial_expiry_date" => "2023-07-14"}
      })

      assert Repo.reload!(user).trial_expiry_date == expiry_date
    end

    test "redirects user to /settings", %{conn: conn} do
      conn = put(conn, "/settings", %{"user" => %{"name" => "New name"}})

      assert redirected_to(conn, 302) == "/settings"
    end

    test "renders form with error if form validations fail", %{conn: conn} do
      conn = put(conn, "/settings", %{"user" => %{"name" => ""}})

      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end
  end

  describe "PUT /settings/email" do
    setup [:create_user, :log_in]

    test "updates email and forces reverification", %{conn: conn, user: user} do
      password = "very-long-very-secret-123"

      user
      |> User.set_password(password)
      |> Repo.update!()

      assert user.email_verified

      conn =
        put(conn, "/settings/email", %{
          "user" => %{"email" => "new" <> user.email, "password" => password}
        })

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :activate)

      updated_user = Repo.reload!(user)

      assert updated_user.email == "new" <> user.email
      assert updated_user.previous_email == user.email
      refute updated_user.email_verified

      assert_delivered_email_matches(%{to: [{_, user_email}], subject: subject})
      assert user_email == updated_user.email
      assert subject =~ "is your Plausible email verification code"
    end

    test "renders form with error on no fields filled", %{conn: conn} do
      conn = put(conn, "/settings/email", %{"user" => %{}})

      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end

    test "renders form with error on invalid password", %{conn: conn, user: user} do
      conn =
        put(conn, "/settings/email", %{
          "user" => %{"password" => "invalid", "email" => "new" <> user.email}
        })

      assert html_response(conn, 200) =~ "is invalid"
    end

    test "renders form with error on already taken email", %{conn: conn, user: user} do
      other_user = insert(:user)

      password = "very-long-very-secret-123"

      user
      |> User.set_password(password)
      |> Repo.update!()

      conn =
        put(conn, "/settings/email", %{
          "user" => %{"password" => password, "email" => other_user.email}
        })

      assert html_response(conn, 200) =~ "has already been taken"
    end

    test "renders form with error when email is identical with the current one", %{
      conn: conn,
      user: user
    } do
      password = "very-long-very-secret-123"

      user
      |> User.set_password(password)
      |> Repo.update!()

      conn =
        put(conn, "/settings/email", %{
          "user" => %{"password" => password, "email" => user.email}
        })

      assert html_response(conn, 200) =~ "can&#39;t be the same"
    end
  end

  describe "POST /settings/email/cancel" do
    setup [:create_user, :log_in]

    test "cancels email reverification in progress", %{conn: conn, user: user} do
      user =
        user
        |> Ecto.Changeset.change(
          email_verified: false,
          email: "new" <> user.email,
          previous_email: user.email
        )
        |> Repo.update!()

      conn = post(conn, "/settings/email/cancel")

      assert redirected_to(conn, 302) ==
               Routes.auth_path(conn, :user_settings) <> "#change-email-address"

      updated_user = Repo.reload!(user)

      assert updated_user.email_verified
      assert updated_user.email == user.previous_email
      refute updated_user.previous_email
    end

    test "fails to cancel reverification when previous email is already retaken", %{
      conn: conn,
      user: user
    } do
      user =
        user
        |> Ecto.Changeset.change(
          email_verified: false,
          email: "new" <> user.email,
          previous_email: user.email
        )
        |> Repo.update!()

      _other_user = insert(:user, email: user.previous_email)

      conn = post(conn, "/settings/email/cancel")

      assert redirected_to(conn, 302) == Routes.auth_path(conn, :activate_form)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Could not cancel email update"
    end

    test "crashes when previous email is empty on cancel (should not happen)", %{
      conn: conn,
      user: user
    } do
      user
      |> Ecto.Changeset.change(
        email_verified: false,
        email: "new" <> user.email,
        previous_email: nil
      )
      |> Repo.update!()

      assert_raise RuntimeError, ~r/Previous email is empty for user/, fn ->
        post(conn, "/settings/email/cancel")
      end
    end
  end

  describe "DELETE /me" do
    setup [:create_user, :log_in, :create_new_site]
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
      insert(:subscription, user: user, status: Subscription.Status.deleted())
      insert(:subscription, user: user, status: Subscription.Status.active())

      conn = delete(conn, "/me")
      assert redirected_to(conn) == "/"
      assert Repo.reload(site) == nil
      assert Repo.reload(user) == nil
      assert Repo.all(Plausible.Billing.Subscription) == []
    end

    test "deletes sites that the user owns", %{conn: conn, user: user, site: owner_site} do
      viewer_site = insert(:site)
      insert(:site_membership, site: viewer_site, user: user, role: "viewer")

      delete(conn, "/me")

      assert Repo.get(Plausible.Site, viewer_site.id)
      refute Repo.get(Plausible.Site, owner_site.id)
    end
  end

  describe "POST /settings/api-keys" do
    setup [:create_user, :log_in]
    import Ecto.Query

    test "can create an API key", %{conn: conn, user: user} do
      insert(:site, memberships: [build(:site_membership, user: user, role: "owner")])

      conn =
        post(conn, "/settings/api-keys", %{
          "api_key" => %{
            "user_id" => user.id,
            "name" => "all your code are belong to us",
            "key" => "swordfish"
          }
        })

      key = Plausible.Auth.ApiKey |> where(user_id: ^user.id) |> Repo.one()
      assert conn.status == 302
      assert key.name == "all your code are belong to us"
    end

    test "cannot create a duplicate API key", %{conn: conn, user: user} do
      insert(:site, memberships: [build(:site_membership, user: user, role: "owner")])

      conn =
        post(conn, "/settings/api-keys", %{
          "api_key" => %{
            "user_id" => user.id,
            "name" => "all your code are belong to us",
            "key" => "swordfish"
          }
        })

      conn2 =
        post(conn, "/settings/api-keys", %{
          "api_key" => %{
            "user_id" => user.id,
            "name" => "all your code are belong to us",
            "key" => "swordfish"
          }
        })

      assert html_response(conn2, 200) =~ "has already been taken"
    end

    test "can't create api key into another site", %{conn: conn, user: me} do
      _my_site = insert(:site, memberships: [build(:site_membership, user: me, role: "owner")])

      other_user = insert(:user)

      _other_site =
        insert(:site, memberships: [build(:site_membership, user: other_user, role: "owner")])

      conn =
        post(conn, "/settings/api-keys", %{
          "api_key" => %{
            "user_id" => other_user.id,
            "name" => "all your code are belong to us",
            "key" => "swordfish"
          }
        })

      assert conn.status == 302

      refute Plausible.Auth.ApiKey |> where(user_id: ^other_user.id) |> Repo.one()
    end
  end

  describe "DELETE /settings/api-keys/:id" do
    setup [:create_user, :log_in]
    alias Plausible.Auth.ApiKey

    test "can't delete api key that doesn't belong to me", %{conn: conn} do
      other_user = insert(:user)
      insert(:site, memberships: [build(:site_membership, user: other_user, role: "owner")])

      assert {:ok, %ApiKey{} = api_key} =
               %ApiKey{user_id: other_user.id}
               |> ApiKey.changeset(%{"name" => "other user's key"})
               |> Repo.insert()

      conn = delete(conn, "/settings/api-keys/#{api_key.id}")
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Could not find API Key to delete"
      assert Repo.get(ApiKey, api_key.id)
    end
  end

  describe "GET /auth/google/callback" do
    test "shows error and redirects back to settings when authentication fails", %{conn: conn} do
      site = insert(:site)
      callback_params = %{"error" => "access_denied", "state" => "[#{site.id},\"import\"]"}
      conn = get(conn, Routes.auth_path(conn, :google_auth_callback), callback_params)

      assert redirected_to(conn, 302) == Routes.site_path(conn, :settings_general, site.domain)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "unable to authenticate your Google Analytics"
    end
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

  defp configure_enterprise_plan(user) do
    insert(:enterprise_plan,
      paddle_plan_id: @configured_enterprise_plan_paddle_plan_id,
      user: user,
      monthly_pageview_limit: 20_000_000,
      billing_interval: :yearly
    )
  end
end
