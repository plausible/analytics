defmodule Mix.Tasks.SendIntroEmailsTest do
  use Plausible.DataCase
  use Bamboo.Test

  describe "when user has not managed to set up a site" do
    test "does not send an email 5 hours after signup" do
      {:ok, _user} = create_user(%{inserted_at: hours_ago(5)})

      Mix.Tasks.SendIntroEmails.run()

      assert_no_emails_delivered()
    end

    test "sends a setup help email 6 hours after signup" do
      {:ok, user} = create_user(%{inserted_at: hours_ago(6)})

      Mix.Tasks.SendIntroEmails.run()

      assert_email_delivered_with(
        to: [nil: user.email],
        subject: "Plausible setup"
      )
    end

    test "sends a setup help email 23 hours after signup" do
      {:ok, user} = create_user(%{inserted_at: hours_ago(23)})

      Mix.Tasks.SendIntroEmails.run()

      assert_email_delivered_with(
        to: [nil: user.email],
        subject: "Plausible setup"
      )
    end

    test "does not send an email 24 hours after signup" do
      {:ok, _user} = create_user(%{inserted_at: hours_ago(24)})

      Mix.Tasks.SendIntroEmails.run()

      assert_no_emails_delivered()
    end
  end

  describe "when user has managed to set up their first site" do
    test "does not send an email 5 hours after signup" do
      {:ok, _user} = create_user(%{inserted_at: hours_ago(5)})

      Mix.Tasks.SendIntroEmails.run()

      assert_no_emails_delivered()
    end

    test "sends a setup help email 6 hours after signup if the user has created a site but has not received a pageview yet" do
      {:ok, user} = create_user(%{inserted_at: hours_ago(6)})
      create_site(user.id)

      Mix.Tasks.SendIntroEmails.run()

      assert_email_delivered_with(
        to: [nil: user.email],
        subject: "Plausible setup"
      )
    end

    test "sends a welcome email 6 hours after signup if the user has created a site and has received a pageview" do
      {:ok, user} = create_user(%{inserted_at: hours_ago(6)})
      site = create_site(user.id)
      create_pageview(site.domain)

      Mix.Tasks.SendIntroEmails.run()

      assert_email_delivered_with(
        to: [nil: user.email],
        subject: "Plausible feedback"
      )
    end

    test "sends a welcome email 23 hours after signup" do
      {:ok, user} = create_user(%{inserted_at: hours_ago(23)})
      site = create_site(user.id)
      create_pageview(site.domain)

      Mix.Tasks.SendIntroEmails.run()

      assert_email_delivered_with(
        to: [nil: user.email],
        subject: "Plausible feedback"
      )
    end

    test "does not send a welcome email 24 hours after signup" do
      {:ok, user} = create_user(%{inserted_at: hours_ago(24)})
      site = create_site(user.id)
      create_pageview(site.domain)

      Mix.Tasks.SendIntroEmails.run()

      assert_no_emails_delivered()
    end
  end

  test "does not send two intro emails to the same person" do
    {:ok, user} = create_user(%{inserted_at: hours_ago(12)})

    Mix.Tasks.SendIntroEmails.run()

    site = create_site(user.id)
    create_pageview(site.domain)

    Mix.Tasks.SendIntroEmails.run()

    assert_delivered_email(PlausibleWeb.Email.help_email(user))
    refute_delivered_email(PlausibleWeb.Email.welcome_email(user))
  end

  defp create_user(attrs) do
    %Plausible.Auth.User{
      name: "Jane Doe",
      email: "user@example.com"
    }
    |> Map.merge(attrs)
    |> Repo.insert()
  end

  defp create_site(user_id) do
    site = %Plausible.Site{
      domain: "example.com",
      timezone: "Etc/Greenwich"
    } |> Repo.insert!()

    %Plausible.Site.Membership{
      user_id: user_id,
      site_id: site.id
    } |> Repo.insert!
    site
  end

  defp create_pageview(domain) do
    %Plausible.Pageview{
      hostname: domain,
      pathname: "/",
      new_visitor: true,
      session_id: "123",
      user_id: "321"
    } |> Repo.insert!
  end

  defp hours_ago(hours) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> Timex.shift(hours: -hours)
  end
end
