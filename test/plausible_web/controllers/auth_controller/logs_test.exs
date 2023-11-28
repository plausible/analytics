defmodule PlausibleWeb.AuthController.LogsTest do
  use PlausibleWeb.ConnCase
  import ExUnit.CaptureLog

  setup {PlausibleWeb.FirstLaunchPlug.Test, :skip}

  describe "POST /login" do
    setup do
      patch_env(:log_failed_login_attempts, true)
    end

    test "logs on missing user", %{conn: conn} do
      logs =
        capture_log(fn ->
          post(conn, "/login", email: "user@example.com", password: "password")
        end)

      assert logs =~ "[warning] [login] user not found for user@example.com"
    end

    test "logs on wrong password", %{conn: conn} do
      user = insert(:user, password: "password")

      logs =
        capture_log(fn ->
          post(conn, "/login", email: user.email, password: "wrong")
        end)

      assert logs =~ "[warning] [login] wrong password for #{user.email}"
    end

    test "logs on too many login attempts", %{conn: conn} do
      user = insert(:user, password: "password")

      capture_log(fn ->
        for _ <- 1..5 do
          build_conn()
          |> put_req_header("x-forwarded-for", "1.1.1.1")
          |> post("/login", email: user.email, password: "wrong")
        end
      end)

      logs =
        capture_log(fn ->
          conn
          |> put_req_header("x-forwarded-for", "1.1.1.1")
          |> post("/login", email: user.email, password: "wrong")
        end)

      assert logs =~ "[warning] [login] too many logging attempts for #{user.email}"
    end
  end
end
