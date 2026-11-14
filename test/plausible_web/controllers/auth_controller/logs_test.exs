defmodule PlausibleWeb.AuthController.LogsTest do
  use PlausibleWeb.ConnCase
  import ExUnit.CaptureLog

  setup {PlausibleWeb.FirstLaunchPlug.Test, :skip}

  describe "POST /login" do
    setup do
      patch_env(:log_failed_login_attempts, true)
    end

    test "logs on missing user", %{conn: conn} do
      conn = conn |> delete_req_header("x-forwarded-for") |> Map.put(:remote_ip, {192, 0, 2, 10})

      logs =
        capture_log(fn ->
          post(conn, "/login", email: "user@example.com", password: "password")
        end)

      assert logs =~
               ~s([warning] [login] user not found for user@example.com source_ip="192.0.2.10")
    end

    test "logs on wrong password", %{conn: conn} do
      user = insert(:user, password: "password")
      conn = put_req_header(conn, "x-forwarded-for", "2001:db8::10, 192.0.2.1")

      logs =
        capture_log(fn ->
          post(conn, "/login", email: user.email, password: "wrong")
        end)

      assert logs =~
               ~s([warning] [login] wrong password for #{user.email} source_ip="2001:db8::10")
    end

    test "does not log failed attempts when disabled", %{conn: conn} do
      patch_env(:log_failed_login_attempts, false)

      logs =
        capture_log(fn ->
          post(conn, "/login", email: "user@example.com", password: "password")
        end)

      refute logs =~ "[login]"
    end

    test "does not log successful login attempts", %{conn: conn} do
      user = insert(:user, password: "password")

      {conn, logs} =
        with_log(fn ->
          post(conn, "/login", email: user.email, password: "password")
        end)

      assert conn.status == 302
      refute logs =~ "[login]"
    end

    test "logs on too many login attempts" do
      user = insert(:user, password: "password")

      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", "1.1.1.1")

      logs =
        eventually(
          fn ->
            capture_log(fn ->
              Enum.each(1..5, fn _ ->
                post(conn, "/login", email: user.email, password: "wrong")
              end)
            end)

            {conn, logs} =
              with_log(fn ->
                post(conn, "/login", email: user.email, password: "wrong")
              end)

            {conn.status == 429, logs}
          end,
          500
        )

      assert logs =~
               ~s([warning] [login] too many login attempts for #{user.email} source_ip="1.1.1.1")
    end
  end

  describe "2FA failures" do
    setup %{conn: conn} do
      patch_env(:log_failed_login_attempts, true)
      user = insert(:user, password: "password")
      {:ok, user, _} = Plausible.Auth.TOTP.initiate(user)
      {:ok, user, _} = Plausible.Auth.TOTP.enable(user, :skip_verify)

      conn =
        conn
        |> post("/login", email: user.email, password: "password")
        |> recycle()
        |> prepare_conn()
        |> put_req_header("x-forwarded-for", "192.0.2.20")

      {:ok, conn: conn, user: user}
    end

    test "logs the client IP on an invalid verification code", %{conn: conn, user: user} do
      {conn, logs} =
        with_log(fn ->
          post(conn, "/2fa/verify", code: "invalid")
        end)

      assert conn.status == 200

      assert logs =~
               ~s([warning] [login] wrong 2FA verification code provided for #{user.email} source_ip="192.0.2.20")
    end

    test "logs the client IP on an invalid recovery code", %{conn: conn, user: user} do
      {conn, logs} =
        with_log(fn ->
          post(conn, "/2fa/use_recovery_code", recovery_code: "invalid")
        end)

      assert conn.status == 200

      assert logs =~
               ~s([warning] [login] wrong 2FA recovery code provided for #{user.email} source_ip="192.0.2.20")
    end

    test "logs the client IP on too many verification attempts", %{conn: conn, user: user} do
      conn = put_req_header(conn, "x-forwarded-for", "192.0.2.21")

      logs =
        eventually(
          fn ->
            capture_log(fn ->
              Enum.each(1..5, fn _ ->
                post(conn, "/2fa/verify", code: "invalid")
              end)
            end)

            {conn, logs} = with_log(fn -> post(conn, "/2fa/verify", code: "invalid") end)

            {conn.status == 429, logs}
          end,
          500
        )

      assert logs =~
               ~s([warning] [login] too many login attempts for #{user.email} source_ip="192.0.2.21")
    end
  end
end
