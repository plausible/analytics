defmodule Mix.Tasks.SendSiteSetupEmails do
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
    send_create_site_emails(args)
    send_setup_help_emails(args)
    send_setup_success_emails(args)
  end

  defp send_create_site_emails(args) do
    q =
      from(s in Plausible.Auth.User,
        left_join: se in "create_site_emails", on: se.user_id == s.id,
        where: is_nil(se.id),
        where: s.inserted_at > fragment("(now() at time zone 'utc') - '72 hours'::interval") and s.inserted_at < fragment("(now() at time zone 'utc') - '48 hours'::interval"),
        preload: :sites
      )

    for user <- Repo.all(q) do
      if Enum.count(user.sites) == 0 do
        send_create_site_email(args, user)
      end
    end
  end

  defp send_setup_help_emails(args) do
    q =
      from(s in Plausible.Site,
        left_join: se in "setup_help_emails", on: se.site_id == s.id,
        where: is_nil(se.id),
        where: s.inserted_at > fragment("(now() at time zone 'utc') - '72 hours'::interval"),
        preload: :members
      )

    for site <- Repo.all(q) do
      owner = List.first(site.members)

      setup_completed = Plausible.Sites.has_pageviews?(site)
      hours_passed = Timex.diff(Timex.now(), site.inserted_at, :hours)

      if !setup_completed && hours_passed > 47 do
        send_setup_help_email(args, owner, site)
      end
    end
  end

  defp send_setup_success_emails(args) do
    q =
      from(s in Plausible.Site,
        left_join: se in "setup_success_emails", on: se.site_id == s.id,
        where: is_nil(se.id),
        where: s.inserted_at > fragment("(now() at time zone 'utc') - '72 hours'::interval"),
        preload: :members
      )

    for site <- Repo.all(q) do
      owner = List.first(site.members)

      if Plausible.Sites.has_pageviews?(site) do
        send_setup_success_email(args, owner, site)
      end
    end
  end

  defp send_create_site_email(["--dry-run"], user) do
    Logger.info("DRY RUN: create site email for #{user.name}")
  end

  defp send_create_site_email(_, user) do
    PlausibleWeb.Email.create_site_email(user)
    |> Plausible.Mailer.deliver_now()

    Repo.insert_all("create_site_emails", [%{
      user_id: user.id,
      timestamp: NaiveDateTime.utc_now()
    }])
  end

  defp send_setup_success_email(["--dry-run"], _, site) do
    Logger.info("DRY RUN: setup success email for #{site.domain}")
  end

  defp send_setup_success_email(_, user, site) do
    PlausibleWeb.Email.site_setup_success(user, site)
    |> Plausible.Mailer.deliver_now()

    Repo.insert_all("setup_success_emails", [%{
      site_id: site.id,
      timestamp: NaiveDateTime.utc_now()
    }])
  end

  defp send_setup_help_email(["--dry-run"], _, site) do
    Logger.info("DRY RUN: setup help email for #{site.domain}")
  end

  defp send_setup_help_email(_, user, site) do
    PlausibleWeb.Email.site_setup_help(user, site)
    |> Plausible.Mailer.deliver_now()

    Repo.insert_all("setup_help_emails", [%{
      site_id: site.id,
      timestamp: NaiveDateTime.utc_now()
    }])
  end
end
