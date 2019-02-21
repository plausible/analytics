defmodule PlausibleWeb.AuthControllerTest do
  use PlausibleWeb.ConnCase
  use Bamboo.Test
  import Plausible.TestUtils

  describe "GET /onboarding" do
    test "shows the register form", %{conn: conn} do
      conn = get(conn, "/register")

      assert html_response(conn, 200) =~ "Enter your details to get started"
    end

    test "registering sends an activation link", %{conn: conn} do
      post(conn, "/register", user: %{
        name: "Jane Doe",
        email: "user@example.com"
      })

      assert_email_delivered_with(subject: "Plausible activation link")
    end

    test "user sees success page after registering", %{conn: conn} do
      conn = post(conn, "/register", user: %{
        name: "Jane Doe",
        email: "user@example.com"
      })

      assert html_response(conn, 200) =~ "Success!"
    end
  end

  describe "GET /claim-activation" do
    test "creates the user", %{conn: conn} do
      token = Plausible.Auth.Token.sign_activation("Jane Doe", "user@example.com")
      get(conn, "/claim-activation?token=#{token}")

      assert Plausible.Auth.find_user_by(email: "user@example.com")
    end

    test "redirects new user to create a site", %{conn: conn} do
      token = Plausible.Auth.Token.sign_activation("Jane Doe", "user@example.com")
      conn = get(conn, "/claim-activation?token=#{token}")

      assert redirected_to(conn) == "/sites/new"
    end

    test "shows error when user with that email already exists", %{conn: conn} do
      token = Plausible.Auth.Token.sign_activation("Jane Doe", "user@example.com")

      conn = get(conn, "/claim-activation?token=#{token}")
      conn = get(conn, "/claim-activation?token=#{token}")

      assert conn.status == 400
    end
  end

  describe "GET /login_form" do
    test "shows the login form", %{conn: conn} do
      conn = get(conn, "/login")
      assert html_response(conn, 200) =~ "Enter your email to log in"
    end
  end

  describe "POST /login" do

    test "submitting the form sends a login link", %{conn: conn} do
      {:ok, [user: user]} = create_user([])
      post(conn, "/login", email: user.email)

      assert_email_delivered_with(subject: "Plausible login link")
    end

    test "submitting empty email renders form again", %{conn: conn} do
      conn = post(conn, "/login", email: "")

      assert_no_emails_delivered()
      assert html_response(conn, 200) =~ "email is required"
    end

    test "submitting non-existent user email does not send email", %{conn: conn} do
      post(conn, "/login", email: "fake@example.com")

      assert_no_emails_delivered()
    end

    test "user sees success page after registering", %{conn: conn} do
      conn = post(conn, "/login", email: "user@example.com")

      assert html_response(conn, 200) =~ "Success!"
    end
  end

  describe "GET /claim-login" do
    setup [:create_user]

    test "logs the user in", %{conn: conn, user: user} do
      token = Plausible.Auth.Token.sign_login(user.email)
      conn = get(conn, "/claim-login?token=#{token}")

      assert get_session(conn, :current_user_id) == user.id
    end

    test "redirects user to dashboard", %{conn: conn, user: user} do
      token = Plausible.Auth.Token.sign_login(user.email)
      conn = get(conn, "/claim-login?token=#{token}")

      assert redirected_to(conn) == "/"
    end

    test "shows error when user does not exist", %{conn: conn} do
      token = Plausible.Auth.Token.sign_login("nonexistent@user.com")
      conn = get(conn, "/claim-login?token=#{token}")

      assert conn.status == 401
    end
  end

  describe "GET /settings" do
    setup [:create_user, :log_in]

    test "shows the form", %{conn: conn} do
      conn = get(conn, "/settings")
      assert html_response(conn, 200) =~ "Account settings"
    end
  end

  describe "DELETE /me" do
    setup [:create_user, :log_in, :create_site]
    use Plausible.Repo

    test "deletes the user", %{conn: conn, user: user} do
      Repo.insert_all("intro_emails", [%{
        user_id: user.id,
        timestamp: NaiveDateTime.utc_now()
      }])

      conn = delete(conn, "/me")
      assert redirected_to(conn) == "/"
    end
  end
end
