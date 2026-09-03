defmodule PlausibleWeb.Live.RegisterFormSyncTest do
  use PlausibleWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias Plausible.Auth.User
  alias Plausible.Repo

  @attacker_email "attacker@example.com"
  @strong_password "very-long-and-very-secret-123"

  setup do
    # A pre-existing user keeps the instance from being treated as a brand new
    # install, where creating the very first user is allowed and registration is
    # never disabled. Every test here depends on that.
    inviter = new_user()
    site = new_site(owner: inviter)
    invitation = invite_guest(site, "user@email.co", role: :editor, inviter: inviter)

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

    test "register event over the LiveView socket cannot bypass invite_only via an invalid invitation",
         %{conn: conn} do
      mock_captcha_success()

      {:ok, lv, html} = live(conn, "/register/invitation/does-not-exist")

      assert html =~ "This invitation has expired or was revoked"
      refute element_exists?(html, ~s|form[phx-submit="register"]|)

      result =
        render_hook(lv, "register", %{
          "user" => %{
            "name" => "Attacker",
            "email" => @attacker_email,
            "password" => @strong_password
          }
        })

      refute Repo.get_by(User, email: @attacker_email)
      assert {:error, {:redirect, %{to: "/login"}}} = result
    end

    test "registration from a valid invitation still works", %{conn: conn, invitation: invitation} do
      mock_captcha_success()

      {:ok, lv, _html} = live(conn, "/register/invitation/#{invitation.invitation_id}")

      lv
      |> element("form")
      |> render_submit(%{"user" => %{"name" => "Mary Sue", "password" => @strong_password}})

      assert Repo.get_by(User, email: "user@email.co")
    end
  end

  describe "DISABLE_REGISTRATION=true" do
    # Both registration routes redirect on the HTTP page load when fully
    # disabled, so mount under invite_only where the page still loads, then flip
    # to `true` before the event. That's the path the router pipeline never
    # re-checks and the event handler now has to guard on its own.
    setup do
      patch_disable_registration(:invite_only)
    end

    test "register event from a valid invitation cannot bypass a fully disabled instance",
         %{conn: conn, invitation: invitation} do
      mock_captcha_success()

      {:ok, lv, _html} = live(conn, "/register/invitation/#{invitation.invitation_id}")
      patch_disable_registration(true)

      result =
        render_hook(lv, "register", %{
          "user" => %{"name" => "Mary Sue", "password" => @strong_password}
        })

      refute Repo.get_by(User, email: "user@email.co")
      assert {:error, {:redirect, %{to: "/login"}}} = result
    end

    test "register event without a valid invitation cannot bypass a fully disabled instance",
         %{conn: conn} do
      mock_captcha_success()

      {:ok, lv, _html} = live(conn, "/register/invitation/does-not-exist")
      patch_disable_registration(true)

      result =
        render_hook(lv, "register", %{
          "user" => %{
            "name" => "Attacker",
            "email" => @attacker_email,
            "password" => @strong_password
          }
        })

      refute Repo.get_by(User, email: @attacker_email)
      assert {:error, {:redirect, %{to: "/login"}}} = result
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
