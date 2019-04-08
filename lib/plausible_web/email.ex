defmodule PlausibleWeb.Email do
  use Bamboo.Phoenix, view: PlausibleWeb.EmailView
  import Bamboo.PostmarkHelper

  def welcome_email(user) do
    new_email()
    |> to(user.email)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("welcome-email")
    |> subject("Plausible feedback")
    |> render("welcome_email.html", user: user)
  end

  def help_email(user) do
    new_email()
    |> to(user.email)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("help-email")
    |> subject("Plausible setup")
    |> render("help_email.html", user: user)
  end

  def password_reset_email(email, reset_link) do
    new_email()
    |> to(email)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("password-reset-email")
    |> subject("Plausible password reset")
    |> render("password_reset_email.html", reset_link: reset_link)
  end

  def activation_email(user, link) do
    new_email()
    |> to(user.email)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("activation-email")
    |> subject("Plausible activation link")
    |> render("activation_email.html", name: user.name, link: link)
  end

  def feedback(from, text) do
    from = if from == "", do: "anonymous@plausible.io", else: from

    new_email()
    |> to("uku@plausible.io")
    |> from(from)
    |> tag("feedback")
    |> subject("New feedback submission")
    |> text_body(text)
  end
end
