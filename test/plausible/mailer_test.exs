defmodule Plausible.MailerTest do
  use Plausible.DataCase
  use Bamboo.Test

  describe "from" do
    setup do
      {:ok, user: new_user()}
    end

    # see config tests as well
    test "when MAILER_NAME and MAILER_EMAIL", %{user: user} do
      mailer_email = {"John", "custom@mailer.email"}
      patch_env(:mailer_email, mailer_email)

      email = PlausibleWeb.Email.welcome_email(user)
      assert :ok = Plausible.Mailer.send(email)

      assert_delivered_email(email)
      assert email.from == mailer_email
    end

    test "when MAILER_EMAIL", %{user: user} do
      mailer_email = "custom@mailer.email"
      patch_env(:mailer_email, mailer_email)

      email = PlausibleWeb.Email.welcome_email(user)
      assert :ok = Plausible.Mailer.send(email)

      assert_delivered_email(email)
      assert email.from == mailer_email
    end
  end
end
