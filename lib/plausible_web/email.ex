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

  def trial_two_week_reminder(user) do
    new_email()
    |> to(user)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("trial-two-week-reminder")
    |> subject("14 days left on your Plausible trial")
    |> render("trial_two_week_reminder.html", user: user)
  end

  def trial_upgrade_email(user, day, pageviews) do
    new_email()
    |> to(user)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("trial-upgrade-email")
    |> subject("Your Plausible trial ends #{day}")
    |> render("trial_upgrade_email.html", user: user, day: day, pageviews: pageviews)
  end

  def trial_over_email(user) do
    new_email()
    |> to(user)
    |> from("Uku Taht <uku@plausible.io>")
    |> tag("trial-over-email")
    |> subject("Your Plausible trial has ended")
    |> render("trial_over_email.html", user: user)
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

  def weekly_report(email, site, assigns) do
    new_email()
    |> to(email)
    |> from("Plausible Insights <info@plausible.io>")
    |> tag("weekly-report")
    |> subject("Weekly report for #{site.domain}")
    |> render("weekly_report.html", Keyword.put(assigns, :site, site))
  end
end
