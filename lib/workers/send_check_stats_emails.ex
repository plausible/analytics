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
            u.last_seen < fragment("(now() at time zone 'utc') - '7 days'::interval")
      )

    for user <- Repo.all(q) do
      if eligible_for_check_stats_email?(user) do
        send_check_stats_email(user)
      end
    end

    :ok
  end

  defp eligible_for_check_stats_email?(user) do
    sites =
      from(tm in Plausible.Teams.Membership,
        inner_join: t in assoc(tm, :team),
        inner_join: s in assoc(t, :sites),
        left_join: gm in assoc(tm, :guest_memberships),
        where: tm.user_id == ^user.id,
        where: tm.role != :guest or gm.site_id == s.id,
        select: s
      )
      |> Repo.all()
      |> Repo.preload(:weekly_report)

    not Enum.any?(sites, fn site -> site.weekly_report end) and
      Enum.any?(sites, &Plausible.Sites.has_stats?/1)
  end

  defp send_check_stats_email(user) do
    PlausibleWeb.Email.check_stats_email(user)
    |> Plausible.Mailer.send()

    Repo.insert_all("check_stats_emails", [
      %{
        user_id: user.id,
        timestamp: NaiveDateTime.utc_now()
      }
    ])
  end
end
