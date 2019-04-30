defmodule PlausibleWeb.Email do
  use Bamboo.Phoenix, view: PlausibleWeb.EmailView
  import Bamboo.PostmarkHelper

  def welcome_email(user) do
    new_email()
    |> to(user)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("welcome-email")
    |> subject("Welcome to Plausible :) Plus, a quick question...")
    |> render("welcome_email.html", user: user)
  end

  def help_email(user) do
    new_email()
    |> to(user)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("help-email")
    |> subject("Your Plausible setup")
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

  def feedback_survey_email(user) do
    new_email()
    |> to(user)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("feedback-survey-email")
    |> subject("Plausible feedback")
    |> render("feedback_survey.html", user: user)
  end

  def feedback(from, text) do
    from = if from == "", do: "anonymous@plausible.io", else: from

    new_email()
    |> to("uku@plausible.io")
    |> from("feedback@plausible.io")
    |> put_param("ReplyTo", from)
    |> tag("feedback")
    |> subject("New feedback submission")
    |> text_body(text)
  end
end
