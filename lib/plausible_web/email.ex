defmodule PlausibleWeb.Email do
  use Bamboo.Phoenix, view: PlausibleWeb.EmailView

  def login_email(email, login_link) do
    new_email()
    |> to(email)
    |> from("uku@plausible.io")
    |> subject("Plausible login link")
    |> render("login_email.html", login_link: login_link)
  end
end
