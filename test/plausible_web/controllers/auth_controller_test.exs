defmodule PlausibleWeb.AuthControllerTest do
  use PlausibleWeb.ConnCase
  use Bamboo.Test
  import Plausible.TestUtils

  describe "GET /register" do
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

    test "redirects new user to create a password", %{conn: conn} do
      token = Plausible.Auth.Token.sign_activation("Jane Doe", "user@example.com")
      conn = get(conn, "/claim-activation?token=#{token}")

      assert redirected_to(conn) == "/password"
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
      assert html_response(conn, 200) =~ "Enter your email and password"
    end
  end

  describe "POST /login" do
    test "valid email and password - logs the user in", %{conn: conn} do
      user = insert(:user, password: "password")

      conn = post(conn, "/login", email: user.email, password: "password")

      assert get_session(conn, :current_user_id) == user.id
      assert redirected_to(conn) == "/"
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
      user = insert(:user)
      conn = post(conn, "/password/request-reset", %{email: user.email})

      assert html_response(conn, 200) =~ "Success!"
      assert_email_delivered_with(subject: "Plausible password reset")
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

      Repo.insert_all("feedback_emails", [%{
        user_id: user.id,
        timestamp: NaiveDateTime.utc_now()
      }])

      conn = delete(conn, "/me")
      assert redirected_to(conn) == "/"
    end
  end
end
