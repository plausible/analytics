defmodule Plausible.Workers.SendSiteSetupEmails do
  use Plausible.Repo
  use Oban.Worker, queue: :site_setup_emails
  require Logger

  @impl Oban.Worker
  def perform(_job) do
    send_create_site_emails()
    send_setup_help_emails()
    send_setup_success_emails()

    :ok
  end

  defp send_create_site_emails() do
    q =
      from u in Plausible.Auth.User,
        as: :user,
        where:
          not exists(
            from tm in Plausible.Teams.Membership,
              where: tm.user_id == parent_as(:user).id,
              select: true
          ),
        where:
          not exists(
            from se in "create_site_emails",
              where: se.user_id == parent_as(:user).id,
              select: true
          ),
        where:
          u.inserted_at > fragment("(now() at time zone 'utc') - '72 hours'::interval") and
            u.inserted_at < fragment("(now() at time zone 'utc') - '48 hours'::interval")

    for user <- Repo.all(q) do
      send_create_site_email(user)
    end
  end

  defp send_setup_help_emails() do
    q =
      from(s in Plausible.Site,
        left_join: se in "setup_help_emails",
        on: se.site_id == s.id,
        where: is_nil(se.id),
        where: s.inserted_at > fragment("(now() at time zone 'utc') - '72 hours'::interval"),
        preload: [:owners, :team]
      )

    for site <- Repo.all(q) do
      owners = site.owners
      setup_completed = Plausible.Sites.has_stats?(site)
      hours_passed = NaiveDateTime.diff(DateTime.utc_now(), site.inserted_at, :hour)

      if !setup_completed && hours_passed > 47 do
        send_setup_help_email(owners, site)
      end
    end
  end

  defp send_setup_success_emails() do
    q =
      from(s in Plausible.Site,
        left_join: se in "setup_success_emails",
        on: se.site_id == s.id,
        where: is_nil(se.id),
        inner_join: t in assoc(s, :team),
        where: s.inserted_at > fragment("(now() at time zone 'utc') - '72 hours'::interval"),
        preload: [:owners, team: t]
      )

    for site <- Repo.all(q) do
      if Plausible.Sites.has_stats?(site) do
        send_setup_success_email(site)
      end
    end
  end

  defp send_create_site_email(user) do
    PlausibleWeb.Email.create_site_email(user)
    |> Plausible.Mailer.send()

    Repo.insert_all("create_site_emails", [
      %{
        user_id: user.id,
        timestamp: NaiveDateTime.utc_now()
      }
    ])
  end

  defp send_setup_success_email(site) do
    for owner <- site.owners do
      PlausibleWeb.Email.site_setup_success(owner, site.team, site)
      |> Plausible.Mailer.send()
    end

    Repo.insert_all("setup_success_emails", [
      %{
        site_id: site.id,
        timestamp: NaiveDateTime.utc_now()
      }
    ])
  end

  defp send_setup_help_email(users, site) do
    for user <- users do
      PlausibleWeb.Email.site_setup_help(user, site.team, site)
      |> Plausible.Mailer.send()
    end

    Repo.insert_all("setup_help_emails", [
      %{
        site_id: site.id,
        timestamp: NaiveDateTime.utc_now()
      }
    ])
  end
end
