defmodule PlausibleWeb.EmailTest do
  alias PlausibleWeb.Email
  use ExUnit.Case, async: true
  import Plausible.Factory

  describe "base_email layout" do
    test "greets user by first name if user in template assigns" do
      email =
        Email.base_email()
        |> Email.render("activation_email.html", %{
          user: build(:user, name: "John Doe"),
          code: "123"
        })

      assert email.html_body =~ "Hey John,"
    end

    test "greets impersonally when user not in template assigns" do
      email =
        Email.base_email()
        |> Email.render("password_reset_email.html", %{
          reset_link: "imaginary"
        })

      assert email.html_body =~ "Hey,"
    end

    test "renders plausible link" do
      email =
        Email.base_email()
        |> Email.render("cancellation_email.html")

      assert email.html_body =~ plausible_link()
    end

    test "does not render unsubscribe placeholder by default" do
      email =
        Email.base_email()
        |> Email.render("welcome_email.html")

      refute email.html_body =~ "{{{ pm:unsubscribe }}}"
    end

    test "renders unsubscribe placeholder if told" do
      email =
        Email.base_email()
        |> Email.render("welcome_email.html", %{unsubscribe: true})

      assert email.html_body =~ "{{{ pm:unsubscribe }}}"
    end

    test "can be disabled with a nil layout" do
      email =
        Email.base_email(%{layout: nil})
        |> Email.render("welcome_email.html", %{
          user: build(:user, name: "John Doe")
        })

      refute email.html_body =~ "Hey John,"
      refute email.html_body =~ plausible_link()
    end
  end

  def plausible_link() do
    plausible_url = PlausibleWeb.EmailView.plausible_url()
    "<a href=\"#{plausible_url}\">#{plausible_url}</a>"
  end
end
