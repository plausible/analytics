defmodule PlausibleWeb.Live.RegisterFormTest do
  use PlausibleWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Auth.User
  alias Plausible.Repo

  setup :verify_on_exit!

  describe "GET /register" do
    test "renders registration form (raw URL)", %{conn: conn} do
      conn = get(conn, "/register")

      html = html_response(conn, 200)

      assert element_exists?(html, ~s|form[phx-change="validate"][phx-submit="register"]|)
      assert element_exists?(html, ~s|input[type="hidden"][name="_csrf_token"]|)
      assert element_exists?(html, ~s|input#user_name[type="text"][name="user[name]"]|)
      assert element_exists?(html, ~s|input#user_email[type="email"][name="user[email]"]|)

      assert element_exists?(
               html,
               ~s|input#user_password[type="password"][name="user[password]"]|
             )

      assert element_exists?(
               html,
               ~s|input#user_password_confirmation[type="password"][name="user[password_confirmation]"]|
             )

      assert element_exists?(html, ~s|button[type="submit"]|)
    end

    test "renders registration form (LV)", %{conn: conn} do
      lv = get_liveview(conn)
      html = render(lv)

      assert element_exists?(html, ~s|form[phx-change="validate"][phx-submit="register"]|)
      assert element_exists?(html, ~s|input[type="hidden"][name="_csrf_token"]|)
      assert element_exists?(html, ~s|input#user_name[type="text"][name="user[name]"]|)
      assert element_exists?(html, ~s|input#user_email[type="email"][name="user[email]"]|)

      assert element_exists?(
               html,
               ~s|input#user_password[type="password"][name="user[password]"]|
             )

      assert element_exists?(
               html,
               ~s|input#user_password_confirmation[type="password"][name="user[password_confirmation]"]|
             )

      assert element_exists?(html, ~s|button[type="submit"]|)
    end

    test "renders validation errors depending on input", %{conn: conn} do
      lv = get_liveview(conn)

      type_into_input(lv, "user[password]", "too-short")
      html = render(lv)

      assert html =~ "Password is too weak"

      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      html = render(lv)

      refute html =~ "Password is too weak"
    end

    test "creates user entry on valid input", %{conn: conn} do
      mock_captcha_success()

      lv = get_liveview(conn)

      type_into_input(lv, "user[name]", "Mary Sue")
      type_into_input(lv, "user[email]", "mary.sue@plausible.test")
      type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
      type_into_input(lv, "user[password_confirmation]", "very-long-and-very-secret-123")

      html = lv |> element("form") |> render_submit()

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
  end

  test "renders error on failed captcha", %{conn: conn} do
    mock_captcha_failure()

    lv = get_liveview(conn)

    type_into_input(lv, "user[name]", "Mary Sue")
    type_into_input(lv, "user[email]", "mary.sue@plausible.test")
    type_into_input(lv, "user[password]", "very-long-and-very-secret-123")
    type_into_input(lv, "user[password_confirmation]", "very-long-and-very-secret-123")

    html = lv |> element("form") |> render_submit()

    assert html =~ "Please complete the captcha to register"

    refute Repo.one(User)
  end

  defp get_liveview(conn) do
    conn = assign(conn, :live_module, PlausibleWeb.Live.RegisterForm)
    {:ok, lv, _html} = live(conn, "/register")

    lv
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form")
    |> render_change(%{id => "#{text}"})
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
