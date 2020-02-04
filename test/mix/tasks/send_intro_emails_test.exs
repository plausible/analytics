defmodule Mix.Tasks.SendIntroEmailsTest do
  use Plausible.DataCase
  use Bamboo.Test

  describe "when user has not managed to set up a site" do
    test "does not send an email 5 hours after signup" do
      _user = insert(:user, inserted_at: hours_ago(5))

      Mix.Tasks.SendIntroEmails.execute()

      assert_no_emails_delivered()
    end

    test "sends a setup help email 6 hours after signup" do
      user = insert(:user, inserted_at: hours_ago(6))

      Mix.Tasks.SendIntroEmails.execute()

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible setup"
      )
    end

    test "sends a setup help email 23 hours after signup" do
      user = insert(:user, inserted_at: hours_ago(23))

      Mix.Tasks.SendIntroEmails.execute()

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible setup"
      )
    end

    test "does not send an email 24 hours after signup" do
      _user = insert(:user, inserted_at: hours_ago(24))

      Mix.Tasks.SendIntroEmails.execute()

      assert_no_emails_delivered()
    end
  end

  describe "when user has managed to set up their first site" do
    test "does not send an email 5 hours after signup" do
      _user = insert(:user, inserted_at: hours_ago(5))

      Mix.Tasks.SendIntroEmails.execute()

      assert_no_emails_delivered()
    end

    test "sends a setup help email 6 hours after signup if the user has created a site but has not received a pageview yet" do
      user = insert(:user, inserted_at: hours_ago(6))
      insert(:site, members: [user])

      Mix.Tasks.SendIntroEmails.execute()

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible setup"
      )
    end

    test "sends a welcome email 6 hours after signup if the user has created a site and has received a pageview" do
      user = insert(:user, inserted_at: hours_ago(6))
      site = insert(:site, members: [user])
      insert(:pageview, domain: site.domain)

      Mix.Tasks.SendIntroEmails.execute()

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Welcome to Plausible :) Plus, a quick question..."
      )
    end

    test "sends a welcome email 23 hours after signup" do
      user = insert(:user, inserted_at: hours_ago(23))
      site = insert(:site, members: [user])
      insert(:pageview, domain: site.domain)

      Mix.Tasks.SendIntroEmails.execute()

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Welcome to Plausible :) Plus, a quick question..."
      )
    end

    test "does not send a welcome email 24 hours after signup" do
      user = insert(:user, inserted_at: hours_ago(24))
      site = insert(:site, members: [user])
      insert(:pageview, domain: site.domain)

      Mix.Tasks.SendIntroEmails.execute()

      assert_no_emails_delivered()
    end
  end

  test "does not send two intro emails to the same person" do
    user = insert(:user, inserted_at: hours_ago(12))

    Mix.Tasks.SendIntroEmails.execute()

    site = insert(:site, members: [user])
    insert(:pageview, domain: site.domain)

    Mix.Tasks.SendIntroEmails.execute()

    assert_delivered_email(PlausibleWeb.Email.help_email(user))
    refute_delivered_email(PlausibleWeb.Email.welcome_email(user))
  end

  defp hours_ago(hours) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> Timex.shift(hours: -hours)
  end
end
