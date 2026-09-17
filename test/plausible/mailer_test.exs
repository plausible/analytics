defmodule Plausible.MailerTest do
  use Plausible.DataCase
  use Bamboo.Test

  describe "from" do
    setup do
      {:ok, user: insert(:user)}
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

  describe "suppression" do
    @describetag :ee_only

    test "refuses to send to a suppressed address" do
      user = insert(:user, email: "bounced@example.com")

      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: user.email,
          reason: :hard_bounce,
          source: :webhook
        })

      email = PlausibleWeb.Email.welcome_email(user)
      assert {:error, :suppressed} = Plausible.Mailer.send(email)

      refute_delivered_email(email)
    end

    test "sends normally once the address is no longer suppressed" do
      user = insert(:user, email: "reactivated@example.com")
      reviewer = insert(:user)

      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: user.email,
          reason: :hard_bounce,
          source: :webhook
        })

      {:ok, _} = Plausible.EmailSuppressions.reactivate(user.email, reviewer)

      email = PlausibleWeb.Email.welcome_email(user)
      assert :ok = Plausible.Mailer.send(email)

      assert_delivered_email(email)
    end

    test "still sends priority-stream e-mails to a suppressed address" do
      address = "bounced@example.com"

      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: address,
          reason: :hard_bounce,
          source: :webhook
        })

      email = PlausibleWeb.Email.password_reset_email(address, "http://example.com/reset")
      assert :ok = Plausible.Mailer.send(email)

      assert_delivered_email(email)
    end

    test "does not send a non-priority e-mail to a suppressed address, even alongside a priority one" do
      address = "bounced@example.com"

      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: address,
          reason: :hard_bounce,
          source: :webhook
        })

      base_email = PlausibleWeb.Email.welcome_email(insert(:user, email: address))

      priority_email =
        PlausibleWeb.Email.password_reset_email(address, "http://example.com/reset")

      assert {:error, :suppressed} = Plausible.Mailer.send(base_email)
      assert :ok = Plausible.Mailer.send(priority_email)

      refute_delivered_email(base_email)
      assert_delivered_email(priority_email)
    end
  end
end
