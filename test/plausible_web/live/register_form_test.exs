defmodule PlausibleWeb.Live.RegisterFormTest do
  use PlausibleWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Auth.User
  alias Plausible.Repo

  setup :verify_on_exit!

  describe "/register" do
    test "renders registration form (LV)", %{conn: conn} do
      lv = get_liveview(conn, "/register")
      html = render(lv)

      assert element_exists?(html, ~s|form[phx-change="validate"][phx-submit="register"]|)
      assert element_exists?(html, ~s|input[type="hidden"][name="_csrf_token"]|)
      assert element_exists?(html, ~s|input#register-form_name[type="text"][name="user[name]"]|)

      assert element_exists?(
               html,
               ~s|input#register-form_email[type="email"][name="user[email]"]|
             )

      assert element_exists?(
               html,
               ~s|input#register-form_password[type="password"][name="user[password]"]|
             )

      assert element_exists?(
               html,
               ~s|input#register-form_password_confirmation[type="password"][name="user[password_confirmation]"]|
             )

      assert element_exists?(html, ~s|button[type="submit"]|)
    end

    test "renders validation errors depending on input", %{conn: conn} do
      lv = get_liveview(conn, "/register")

      type_into_input(lv, "user[password]", "too-short")
      html = render(lv)

      assert html =~ "Password is too weak"

      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      html = render(lv)

      refute html =~ "Password is too weak"
    end

    test "creates user entry on valid input", %{conn: conn} do
      mock_captcha_success()

      lv = get_liveview(conn, "/register")

      type_into_input(lv, "user[name]", "Mary Sue")
      type_into_input(lv, "user[email]", "mary.sue@plausible.test")
      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      type_into_input(lv, "user[password_confirmation]", "very-long-and-very-secret-123")

      html = lv |> element("form") |> render_submit()

      on_ee do
        assert_push_event(lv, "send-metrics", %{event_name: "Signup"})
      end

      assert [
               csrf_input,
               name_input,
               email_input,
               password_input,
               password_confirmation_input | _
             ] = find(html, "input")

      assert String.length(text_of_attr(csrf_input, "value")) > 0
      assert text_of_attr(name_input, "value") == "Mary Sue"
      assert text_of_attr(email_input, "value") == "mary.sue@plausible.test"
      assert text_of_attr(password_input, "value") == "very-long-and-very-secret-123"
      assert text_of_attr(password_confirmation_input, "value") == "very-long-and-very-secret-123"

      assert %{
               name: "Mary Sue",
               email: "mary.sue@plausible.test",
               password_hash: password_hash
             } = Repo.one(User)

      assert String.length(password_hash) > 0
    end

    test "renders only one error on empty password confirmation", %{conn: conn} do
      mock_captcha_success()

      lv = get_liveview(conn, "/register")

      type_into_input(lv, "user[name]", "Mary Sue")
      type_into_input(lv, "user[email]", "mary.sue@plausible.test")
      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      type_into_input(lv, "user[password_confirmation]", "")

      html = lv |> element("form") |> render_submit()

      assert html =~ "does not match confirmation"
      refute html =~ "can't be blank"
    end

    test "renders error on failed captcha", %{conn: conn} do
      mock_captcha_failure()

      lv = get_liveview(conn, "/register")

      type_into_input(lv, "user[name]", "Mary Sue")
      type_into_input(lv, "user[email]", "mary.sue@plausible.test")
      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      type_into_input(lv, "user[password_confirmation]", "very-long-and-very-secret-123")

      html = lv |> element("form") |> render_submit()

      assert html =~ "Please complete the captcha to register"

      refute Repo.one(User)
    end

    test "pushing send-metrics-after event submits the form", %{conn: conn} do
      lv = get_liveview(conn, "/register")

      refute render(lv) =~ ~s|phx-trigger-action="phx-trigger-action"|

      render_hook(lv, "send-metrics-after", %{event_name: "Signup", params: %{}})

      assert render(lv) =~ ~s|phx-trigger-action="phx-trigger-action"|
    end
  end

  describe "/register/invitation/:invitation_id" do
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

      {:ok, %{site: site, invitation: invitation, inviter: inviter}}
    end

    test "registers user from invitation", %{conn: conn, invitation: invitation} do
      mock_captcha_success()

      lv = get_liveview(conn, "/register/invitation/#{invitation.invitation_id}")

      type_into_input(lv, "user[name]", "Mary Sue")
      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      type_into_input(lv, "user[password_confirmation]", "very-long-and-very-secret-123")

      html = lv |> element("form") |> render_submit()

      on_ee do
        assert_push_event(lv, "send-metrics", %{event_name: "Signup via invitation"})
      end

      assert [
               csrf_input,
               email_input,
               name_input,
               password_input,
               password_confirmation_input | _
             ] = find(html, "input")

      assert String.length(text_of_attr(csrf_input, "value")) > 0
      assert text_of_attr(name_input, "value") == "Mary Sue"
      assert text_of_attr(email_input, "value") == "user@email.co"
      assert text_of_attr(password_input, "value") == "very-long-and-very-secret-123"
      assert text_of_attr(password_confirmation_input, "value") == "very-long-and-very-secret-123"

      assert %{
               name: "Mary Sue",
               email: "user@email.co",
               password_hash: password_hash,
               # leaves trial_expiry_date null when invitation role is not :owner
               trial_expiry_date: nil
             } = Repo.get_by(User, email: "user@email.co")

      assert String.length(password_hash) > 0
    end

    test "preserves trial_expiry_date when invitation role is :owner", %{
      conn: conn,
      site: site,
      inviter: inviter
    } do
      mock_captcha_success()

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: inviter,
          email: "owner_user@email.co",
          role: :owner
        )

      lv = get_liveview(conn, "/register/invitation/#{invitation.invitation_id}")

      type_into_input(lv, "user[name]", "Mary Sue")
      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      type_into_input(lv, "user[password_confirmation]", "very-long-and-very-secret-123")

      _html = lv |> element("form") |> render_submit()

      assert %{
               email: "owner_user@email.co",
               trial_expiry_date: trial_expiry_date
             } = Repo.get_by(User, email: "owner_user@email.co")

      assert trial_expiry_date != nil
    end

    test "always uses original email from the invitation", %{conn: conn, invitation: invitation} do
      mock_captcha_success()

      lv = get_liveview(conn, "/register/invitation/#{invitation.invitation_id}")

      type_into_input(lv, "user[name]", "Mary Sue")
      type_into_input(lv, "user[email]", "mary.sue@plausible.test")
      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      type_into_input(lv, "user[password_confirmation]", "very-long-and-very-secret-123")

      html = lv |> element("form") |> render_submit()

      assert [
               _csrf_input,
               email_input | _
             ] = find(html, "input")

      # attempt at tampering with form
      assert text_of_attr(email_input, "value") == "mary.sue@plausible.test"

      assert Repo.get_by(User, email: "user@email.co")
      refute Repo.get_by(User, email: "mary.sue@plausible.test")
    end

    test "renders error on failed captcha", %{conn: conn, invitation: invitation} do
      mock_captcha_failure()

      lv = get_liveview(conn, "/register/invitation/#{invitation.invitation_id}")

      type_into_input(lv, "user[name]", "Mary Sue")
      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      type_into_input(lv, "user[password_confirmation]", "very-long-and-very-secret-123")

      html = lv |> element("form") |> render_submit()

      assert html =~ "Please complete the captcha to register"

      refute Repo.get_by(User, email: "user@email.co")
    end

    test "pushing send-metrics-after event submits the form", %{
      conn: conn,
      invitation: invitation
    } do
      lv = get_liveview(conn, "/register/invitation/#{invitation.invitation_id}")

      refute render(lv) =~ ~s|phx-trigger-action="phx-trigger-action"|

      render_hook(lv, "send-metrics-after", %{event_name: "Signup via invitation", params: %{}})

      assert render(lv) =~ ~s|phx-trigger-action="phx-trigger-action"|
    end
  end

  defp get_liveview(conn, url) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.RegisterForm)
    {:ok, lv, _html} = live(conn, url)

    lv
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form")
    |> render_change(%{id => text})
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
