defmodule PlausibleWeb.AuthControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Bamboo.Test
  use Plausible.Repo

  import Mox
  setup :verify_on_exit!

  describe "GET /register" do
    test "shows the register form", %{conn: conn} do
      conn = get(conn, "/register")

      assert html_response(conn, 200) =~ "Enter your details"
    end
  end

  describe "POST /register" do
    setup do
      mock_captcha_success()
      :ok
    end

    test "registering sends an activation link", %{conn: conn} do
      post(conn, "/register",
        user: %{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret",
          password_confirmation: "very-secret"
        }
      )

      assert_delivered_email_matches(%{to: [{_, user_email}], subject: subject})
      assert user_email == "user@example.com"
      assert subject =~ "is your Plausible email verification code"
    end

    test "user is redirected to activate page after registration", %{conn: conn} do
      conn =
        post(conn, "/register",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret",
            password_confirmation: "very-secret"
          }
        )

      assert redirected_to(conn, 302) == "/activate"
    end

    test "creates user record", %{conn: conn} do
      post(conn, "/register",
        user: %{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret",
          password_confirmation: "very-secret"
        }
      )

      user = Repo.one(Plausible.Auth.User)
      assert user.name == "Jane Doe"
    end

    test "logs the user in", %{conn: conn} do
      conn =
        post(conn, "/register",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret",
            password_confirmation: "very-secret"
          }
        )

      assert get_session(conn, :current_user_id)
    end

    test "user is redirected to activation after registration", %{conn: conn} do
      conn =
        post(conn, "/register",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret",
            password_confirmation: "very-secret"
          }
        )

      assert redirected_to(conn) == "/activate"
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
      mock_captcha_success()
      inviter = insert(:user)
      site = insert(:site, members: [inviter])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: inviter,
          email: "user@email.co",
          role: :admin
        )

      {:ok, %{site: site, invitation: invitation}}
    end

    test "registering sends an activation link", %{conn: conn, invitation: invitation} do
      post(conn, "/register/invitation/#{invitation.invitation_id}",
        user: %{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret",
          password_confirmation: "very-secret"
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
            password: "very-secret",
            password_confirmation: "very-secret"
          }
        )

      assert redirected_to(conn, 302) == "/activate"
    end

    test "creates user record", %{conn: conn, invitation: invitation} do
      post(conn, "/register/invitation/#{invitation.invitation_id}",
        user: %{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret",
          password_confirmation: "very-secret"
        }
      )

      user = Repo.get_by(Plausible.Auth.User, email: "user@example.com")
      assert user.name == "Jane Doe"
    end

    test "leaves trial_expiry_date null when invitation role is not :owner", %{
      conn: conn,
      invitation: invitation
    } do
      post(conn, "/register/invitation/#{invitation.invitation_id}",
        user: %{
          name: "Jane Doe",
          email: "user@example.com",
          password: "very-secret",
          password_confirmation: "very-secret"
        }
      )

      user = Repo.get_by(Plausible.Auth.User, email: "user@example.com")
      assert is_nil(user.trial_expiry_date)
    end

    test "logs the user in", %{conn: conn, invitation: invitation} do
      conn =
        post(conn, "/register/invitation/#{invitation.invitation_id}",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret",
            password_confirmation: "very-secret"
          }
        )

      assert get_session(conn, :current_user_id)
    end

    test "user is redirected to activation after registration", %{conn: conn} do
      conn =
        post(conn, "/register",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret",
            password_confirmation: "very-secret"
          }
        )

      assert redirected_to(conn) == "/activate"
    end
  end

  describe "captcha failure" do
    setup do
      mock_captcha_failure()
      inviter = insert(:user)
      site = insert(:site, members: [inviter])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: inviter,
          email: "user@email.co",
          role: :admin
        )

      {:ok, %{site: site, invitation: invitation}}
    end

    test "renders captcha errors in case of captcha input verification failure", %{
      conn: conn,
      invitation: invitation
    } do
      conn =
        post(conn, "/register/invitation/#{invitation.invitation_id}",
          user: %{
            name: "Jane Doe",
            email: "user@example.com",
            password: "very-secret",
            password_confirmation: "very-secret"
          }
        )

      assert html_response(conn, 200) =~ "Please complete the captcha"
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

    test "associates an activation pin with the user account", %{conn: conn, user: user} do
      post(conn, "/activate/request-code")

      code =
        Repo.one(
          from c in "email_verification_codes",
            where: c.user_id == ^user.id,
            select: %{user_id: c.user_id, issued_at: c.issued_at}
        )

      assert code[:user_id] == user.id
      assert Timex.after?(code[:issued_at], Timex.now() |> Timex.shift(seconds: -10))
    end

    test "sends activation email to user", %{conn: conn, user: user} do
      post(conn, "/activate/request-code")

      assert_delivered_email_matches(%{to: [{_, user_email}], subject: subject})
      assert user_email == user.email
      assert subject =~ "is your Plausible email verification code"
    end

    test "redirets user to /activate", %{conn: conn} do
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
      Repo.insert_all("email_verification_codes", [
        %{
          code: 1234,
          user_id: user.id,
          issued_at: Timex.shift(Timex.now(), days: -1)
        }
      ])

      conn = post(conn, "/activate", %{code: "1234"})

      assert html_response(conn, 200) =~ "Code is expired, please request another one"
    end

    test "marks the user account as active", %{conn: conn, user: user} do
      Repo.update!(Plausible.Auth.User.changeset(user, %{email_verified: false}))
      post(conn, "/activate/request-code")

      code =
        Repo.one(
          from c in "email_verification_codes", where: c.user_id == ^user.id, select: c.code
        )
        |> Integer.to_string()

      conn = post(conn, "/activate", %{code: code})
      user = Repo.get_by(Plausible.Auth.User, id: user.id)

      assert user.email_verified
      assert redirected_to(conn) == "/sites/new"
    end

    test "redirects to /sites if user has invitation", %{conn: conn, user: user} do
      site = insert(:site)
      insert(:invitation, inviter: build(:user), site: site, email: user.email)
      Repo.update!(Plausible.Auth.User.changeset(user, %{email_verified: false}))
      post(conn, "/activate/request-code")

      code =
        Repo.one(
          from c in "email_verification_codes", where: c.user_id == ^user.id, select: c.code
        )
        |> Integer.to_string()

      conn = post(conn, "/activate", %{code: code})

      assert redirected_to(conn) == "/sites"
    end

    test "removes the user association from the verification code", %{conn: conn, user: user} do
      Repo.update!(Plausible.Auth.User.changeset(user, %{email_verified: false}))
      post(conn, "/activate/request-code")

      code =
        Repo.one(
          from c in "email_verification_codes", where: c.user_id == ^user.id, select: c.code
        )
        |> Integer.to_string()

      post(conn, "/activate", %{code: code})

      refute Repo.exists?(from c in "email_verification_codes", where: c.user_id == ^user.id)
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
      token = Plausible.Auth.Token.sign_password_reset("email@example.com")
      conn = get(conn, "/password/reset", %{token: token})

      assert html_response(conn, 200) =~ "Reset your password"
    end

    test "with invalid token - shows error page", %{conn: conn} do
      conn = get(conn, "/password/reset", %{token: "blabla"})

      assert html_response(conn, 401) =~ "Your token is invalid"
    end
  end

  describe "POST /password/reset" do
    alias Plausible.Auth.{User, Token, Password}

    test "with valid token - resets the password", %{conn: conn} do
      user = insert(:user)
      token = Token.sign_password_reset(user.email)
      post(conn, "/password/reset", %{token: token, password: "new-password"})

      user = Plausible.Repo.get(User, user.id)
      assert Password.match?("new-password", user.password_hash)
    end

    test "with valid token - redirects the user to login and shows success message", %{conn: conn} do
      user = insert(:user)
      token = Token.sign_password_reset(user.email)
      conn = post(conn, "/password/reset", %{token: token, password: "new-password"})

      assert location = "/login" = redirected_to(conn, 302)

      conn = get(recycle(conn), location)
      assert html_response(conn, 200) =~ "Password updated successfully"
    end
  end

  describe "GET /settings" do
    setup [:create_user, :log_in]

    test "shows the form", %{conn: conn} do
      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "Account settings"
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

      insert(:enterprise_plan,
        paddle_plan_id: "123",
        user: user,
        monthly_pageview_limit: 10_000_000,
        billing_interval: :yearly
      )

      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "10M pageviews"
      assert html_response(conn, 200) =~ "yearly billing"
    end

    test "shows current enterprise plan subscription when user has a new one to upgrade to", %{
      conn: conn,
      user: user
    } do
      insert(:subscription, paddle_plan_id: "123", user: user)

      insert(:enterprise_plan,
        paddle_plan_id: "123",
        user: user,
        monthly_pageview_limit: 10_000_000,
        billing_interval: :yearly
      )

      insert(:enterprise_plan,
        paddle_plan_id: "1234",
        user: user,
        monthly_pageview_limit: 20_000_000,
        billing_interval: :yearly
      )

      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "10M pageviews"
      assert html_response(conn, 200) =~ "yearly billing"
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

    test "redirects user to /settings", %{conn: conn} do
      conn = put(conn, "/settings", %{"user" => %{"name" => "New name"}})

      assert redirected_to(conn, 302) == "/settings"
    end

    test "renders form with error if form validations fail", %{conn: conn} do
      conn = put(conn, "/settings", %{"user" => %{"name" => ""}})

      assert html_response(conn, 200) =~ "can&#39;t be blank"
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
      insert(:subscription, user: user, status: "deleted")
      insert(:subscription, user: user, status: "active")

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
      site = insert(:site)
      insert(:site_membership, site: site, user: user, role: "owner")

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
      site = insert(:site)
      insert(:site_membership, site: site, user: user, role: "owner")

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
      my_site = insert(:site)
      insert(:site_membership, site: my_site, user: me, role: "owner")

      other_user = insert(:user)
      other_site = insert(:site)
      insert(:site_membership, site: other_site, user: other_user, role: "owner")

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
      insert(:site_membership, site: insert(:site), user: other_user, role: "owner")

      assert {:ok, %ApiKey{} = api_key} =
               %ApiKey{user_id: other_user.id}
               |> ApiKey.changeset(%{"name" => "other user's key"})
               |> Repo.insert()

      assert_raise Ecto.NoResultsError, fn ->
        delete(conn, "/settings/api-keys/#{api_key.id}")
      end

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
end
