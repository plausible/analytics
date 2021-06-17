defmodule Plausible.Workers.SendCheckStatsEmails do
  use Plausible.Repo
  use Oban.Worker, queue: :check_stats_emails

  @impl Oban.Worker
  def perform(_job) do
    q =
      from(u in Plausible.Auth.User,
        left_join: ce in "check_stats_emails",
        on: ce.user_id == u.id,
        where: is_nil(ce.id),
        where:
          u.inserted_at > fragment("(now() at time zone 'utc') - '14 days'::interval") and
            u.inserted_at < fragment("(now() at time zone 'utc') - '7 days'::interval") and
            u.last_seen < fragment("(now() at time zone 'utc') - '7 days'::interval"),
        preload: [sites: :weekly_report]
      )

    for user <- Repo.all(q) do
      enabled_report = Enum.any?(user.sites, fn site -> site.weekly_report end)

      if Plausible.Auth.has_active_sites?(user) && !enabled_report do
        send_check_stats_email(user)
      end
    end

    :ok
  end

  defp send_check_stats_email(user) do
    PlausibleWeb.Email.check_stats_email(user)
    |> Plausible.Mailer.send_email()

    Repo.insert_all("check_stats_emails", [
      %{
        user_id: user.id,
        timestamp: NaiveDateTime.utc_now()
      }
    ])
  end
end
