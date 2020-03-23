defmodule Mix.Tasks.SendCheckStatsEmails do
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
        left_join: ce in "check_stats_emails", on: ce.user_id == u.id,
        where: is_nil(ce.id),
        where:
        u.inserted_at > fragment("(now() at time zone 'utc') - '14 days'::interval") and
        u.inserted_at < fragment("(now() at time zone 'utc') - '7 days'::interval") and
        u.last_seen < fragment("(now() at time zone 'utc') - '7 days'::interval"),
        preload: [sites: :weekly_report]
      )

    for user <- Repo.all(q) do
      enabled_report = Enum.any?(user.sites, fn site -> site.weekly_report end)

      if Plausible.Auth.user_completed_setup?(user) && !enabled_report do
        send_check_stats_email(args, user)
      end
    end
  end

  defp send_check_stats_email(["--dry-run"], user) do
    Logger.info("DRY RUN: check stats email to #{user.name}")
  end

  defp send_check_stats_email(_, user) do
    PlausibleWeb.Email.check_stats_email(user)
    |> Plausible.Mailer.deliver_now()

    Repo.insert_all("check_stats_emails", [%{
      user_id: user.id,
      timestamp: NaiveDateTime.utc_now()
    }])
  end
end
