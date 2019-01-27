defmodule PlausibleWeb.Email do
  use Bamboo.Phoenix, view: PlausibleWeb.EmailView

  def login_email(email, login_link) do
    new_email()
    |> to(email)
    |> from("uku@plausible.io")
    |> put_header("X-Mailgun-Tag", "login-email")
    |> subject("Plausible login link")
    |> render("login_email.html", login_link: login_link)
  end

  def activation_email(name, email, link) do
    new_email()
    |> to(email)
    |> from("uku@plausible.io")
    |> put_header("X-Mailgun-Tag", "activation-email")
    |> subject("Plausible activation link")
    |> render("activation_email.html", name: name, link: link)
  end
end
