defmodule Mix.Tasks.SendFeedbackEmails do
  use Mix.Task
  use Plausible.Repo
  require Logger

  @doc """
  This is scheduled to run every 6 hours.
  """

  def run(args) do
    Application.ensure_all_started(:plausible)
    execute(args)
  end

  def execute(args \\ []) do
    q =
      from(u in Plausible.Auth.User,
        left_join: fe in "feedback_emails", on: fe.user_id == u.id,
        where: is_nil(fe.id),
        where: u.inserted_at < fragment("(now() at time zone 'utc') - '30 days'::interval"),
        where: u.last_seen > fragment("now() at time zone 'utc' - '7 days'::interval")
      )

    for user <- Repo.all(q) do
      if Plausible.Auth.user_completed_setup?(user) do
        send_feedback_email(args, user)
      end
    end
  end

  defp send_feedback_email(["--dry-run"], user) do
    Logger.info("DRY RUN: feedback survey email to #{user.name}")
  end

  defp send_feedback_email(_, user) do
    PlausibleWeb.Email.feedback_survey_email(user)
    |> Plausible.Mailer.deliver_now()

    feedback_email_sent(user)
  end

  defp feedback_email_sent(user) do
    Repo.insert_all("feedback_emails", [%{
      user_id: user.id,
      timestamp: NaiveDateTime.utc_now()
    }])
  end
end
