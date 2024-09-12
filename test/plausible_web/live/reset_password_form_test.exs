defmodule PlausibleWeb.Live.ResetPasswordFormTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.ChannelTest
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Auth.User
  alias Plausible.Auth.Token
  alias Plausible.Auth.TOTP
  alias Plausible.Repo

  describe "/password/reset" do
    test "sets new password with valid token", %{conn: conn} do
      user = insert(:user)
      token = Token.sign_password_reset(user.email)

      lv = get_liveview(conn, "/password/reset?token=#{token}")

      type_into_passowrd(lv, "very-secret-and-very-long-123")
      html = lv |> element("form") |> render_submit()

      assert [csrf_input, password_input | _] = find(html, "input")
      assert String.length(text_of_attr(csrf_input, "value")) > 0
      assert text_of_attr(password_input, "value") == "very-secret-and-very-long-123"
      assert %{password_hash: new_hash} = Repo.one(User)
      assert new_hash != user.password_hash
    end

    test "reset's user's TOTP token when present", %{conn: conn} do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      {:ok, user, _} = TOTP.enable(user, :skip_verify)

      token = Token.sign_password_reset(user.email)

      lv = get_liveview(conn, "/password/reset?token=#{token}")

      type_into_passowrd(lv, "very-secret-and-very-long-123")
      lv |> element("form") |> render_submit()

      updated_user = Repo.reload!(user)

      assert byte_size(updated_user.totp_token) > 0
      assert updated_user.totp_token != user.totp_token
    end

    test "renders error when new password fails validation", %{conn: conn} do
      user = insert(:user)
      token = Token.sign_password_reset(user.email)

      lv = get_liveview(conn, "/password/reset?token=#{token}")

      type_into_passowrd(lv, "too-short")
      html = lv |> element("form") |> render_submit()

      assert html =~ "Password is too weak"

      assert %{password_hash: hash} = Repo.one(User)
      assert hash == user.password_hash
    end
  end

  describe "/password/reset with logged in user" do
    setup [:create_user, :log_in]

    test "revokes all active user sessions when present", %{conn: conn, user: user} do
      assert [active_session] = Repo.preload(user, :sessions).sessions
      live_socket_id = "user_sessions:" <> Base.url_encode64(active_session.token)
      Phoenix.PubSub.subscribe(Plausible.PubSub, live_socket_id)

      another_session =
        user
        |> Plausible.Auth.UserSession.new_session("Some Device")
        |> Repo.insert!()

      token = Token.sign_password_reset(user.email)

      lv = get_liveview(conn, "/password/reset?token=#{token}")

      type_into_passowrd(lv, "very-secret-and-very-long-123")
      lv |> element("form") |> render_submit()

      assert [] = Repo.preload(user, :sessions).sessions
      assert_broadcast "disconnect", %{}
      refute Repo.reload(another_session)
    end
  end

  defp get_liveview(conn, url) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.ResetPasswordForm)
    {:ok, lv, _html} = live(conn, url)

    lv
  end

  defp type_into_passowrd(lv, text) do
    lv
    |> element("form")
    |> render_change(%{"user[password]" => text})
  end
end
