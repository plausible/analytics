defmodule Mix.Tasks.SendIntroEmails do
  use Mix.Task
  use Plausible.Repo
  require Logger

  @doc """
  This is scheduled to run every 6 hours.
  """

  def run(args) do
    Application.ensure_all_started(:plausible)
    run()
  end

  def run() do
    q =
      from(u in Plausible.Auth.User,
        left_join: ie in "intro_emails", on: ie.user_id == u.id,
        where: is_nil(ie.id),
        where:
          u.inserted_at > fragment("now() - '24 hours'::interval") and
            u.inserted_at < fragment("now() - '6 hours'::interval")
      )

    for user <- Repo.all(q) do
      if user_completed_setup?(user) do
        Logger.info("#{user.name} has completed the setup. Sending welcome email.")
        send_welcome_email(user)
      else
        Logger.info("#{user.name} has not completed the setup. Sending help email.")
        send_help_email(user)
      end
    end
  end

  defp send_welcome_email(user) do
    PlausibleWeb.Email.welcome_email(user)
    |> Plausible.Mailer.deliver_now()

    intro_email_sent(user)
  end

  defp send_help_email(user) do
    PlausibleWeb.Email.help_email(user)
    |> Plausible.Mailer.deliver_now()

    intro_email_sent(user)
  end

  defp intro_email_sent(user) do
    Repo.insert_all("intro_emails", [%{
      user_id: user.id,
      timestamp: NaiveDateTime.utc_now()
    }])
  end

  defp user_completed_setup?(user) do
    query =
      from(
        p in Plausible.Pageview,
        join: s in Plausible.Site,
        on: s.domain == p.hostname,
        join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        join: u in Plausible.Auth.User,
        on: sm.user_id == u.id,
        where: u.id == ^user.id
      )

    Repo.exists?(query)
  end
end
