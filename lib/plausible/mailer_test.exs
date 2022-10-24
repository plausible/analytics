defmodule Plausible.MailerTest do
  use Plausible.DataCase
  use Bamboo.Test

  test "send/1 sends an email" do
    user = build(:user)
    email = PlausibleWeb.Email.welcome_email(user)

    assert :ok == Plausible.Mailer.send(email)
    assert_delivered_email(email)
  end
end
