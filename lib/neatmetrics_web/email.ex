defmodule NeatmetricsWeb.Email do
  use Bamboo.Phoenix, view: NeatmetricsWeb.EmailView

  def login_email(email, login_link) do
    new_email()
    |> to(email)
    |> from("uku@neatmetrics.io")
    |> subject("Neatmetrics login link")
    |> render("login_email.html", login_link: login_link)
  end
end
