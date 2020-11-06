defmodule PlausibleWeb.SiteController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.{Sites, Goals}

  plug PlausibleWeb.RequireAccountPlug

  def index(conn, _params) do
    user = conn.assigns[:current_user] |> Repo.preload(:sites)
    render(conn, "index.html", sites: user.sites)
  end

  def new(conn, _params) do
    changeset = Plausible.Site.changeset(%Plausible.Site{})

    render(conn, "new.html", changeset: changeset, layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def create_site(conn, %{"site" => site_params}) do
    user = conn.assigns[:current_user]

    case insert_site(user.id, site_params) do
      {:ok, %{site: site}} ->
        Plausible.Slack.notify("#{user.name} created #{site.domain} [email=#{user.email}]")

        conn
        |> put_session(site.domain <> "_offer_email_report", true)
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/snippet")

      {:error, :site, changeset, _} ->
        render(conn, "new.html",
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def add_snippet(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:custom_domain)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("snippet.html", site: site, layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def new_goal(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    changeset = Plausible.Goal.changeset(%Plausible.Goal{})

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("new_goal.html",
      site: site,
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def create_goal(conn, %{"website" => website, "goal" => goal}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    case Plausible.Goals.create(site, goal) do
      {:ok, _} ->
        conn
        |> put_flash(:success, "Goal created succesfully")
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings")

      {:error, :goal, changeset, _} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("new_goal.html",
          site: site,
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def delete_goal(conn, %{"website" => website, "id" => goal_id}) do
    Plausible.Goals.delete(goal_id)

    conn
    |> put_flash(:success, "Goal deleted succesfully")
    |> redirect(to: "/#{URI.encode_www_form(website)}/settings")
  end

  def settings(conn, %{"website" => website}) do
    redirect(conn, to: "/#{URI.encode_www_form(website)}/settings/general")
  end

  def settings_general(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:google_auth)
      |> Repo.preload(:custom_domain)

    search_console_domains =
      if site.google_auth do
        Plausible.Google.Api.fetch_verified_properties(site.google_auth)
      end

    weekly_report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    monthly_report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    shared_links = Repo.all(from l in Plausible.Site.SharedLink, where: l.site_id == ^site.id)
    goals = Goals.for_site(site.domain)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings.html",
      site: site,
      weekly_report: weekly_report,
      monthly_report: monthly_report,
      search_console_domains: search_console_domains,
      goals: goals,
      shared_links: shared_links,
      changeset: Plausible.Site.changeset(site, %{})
    )
  end

  def settings_goals(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    goals = Goals.for_site(site.domain)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings_goals.html",
      site: site,
      goals: goals
    )
  end

  def update_google_auth(conn, %{"website" => website, "google_auth" => attrs}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:google_auth)

    Plausible.Site.GoogleAuth.set_property(site.google_auth, attrs)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Google integration saved succesfully")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#google-auth")
  end

  def delete_google_auth(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:google_auth)

    Repo.delete!(site.google_auth)

    conn
    |> put_flash(:success, "Google account unlinked succesfully")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#google-auth")
  end

  def update_settings(conn, %{"website" => website, "site" => site_params}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    changeset = site |> Plausible.Site.changeset(site_params)
    res = changeset |> Repo.update()

    case res do
      {:ok, site} ->
        site_session_key = "authorized_site__" <> site.domain

        conn
        |> put_session(site_session_key, nil)
        |> put_flash(:success, "Site settings saved succesfully")
        |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings")

      {:error, changeset} ->
        render("settings.html", site: site, changeset: changeset)
    end
  end

  def reset_stats(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Plausible.ClickhouseRepo.clear_stats_for(site.domain)

    conn
    |> put_flash(:success, "#{site.domain} stats will be reset in a few minutes")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings")
  end

  def delete_site(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:google_auth)

    Repo.delete_all(from sm in "site_memberships", where: sm.site_id == ^site.id)

    if site.google_auth do
      Repo.delete!(site.google_auth)
    end

    Repo.delete!(site)
    Plausible.ClickhouseRepo.clear_stats_for(site.domain)

    conn
    |> put_flash(:success, "Site deleted succesfully along with all pageviews")
    |> redirect(to: "/sites")
  end

  def make_public(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Plausible.Site.make_public()
      |> Repo.update!()

    conn
    |> put_flash(:success, "Congrats! Stats for #{site.domain} are now public.")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings")
  end

  def make_private(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Plausible.Site.make_private()
      |> Repo.update!()

    conn
    |> put_flash(:success, "Stats for #{site.domain} are now private.")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings")
  end

  def enable_weekly_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Plausible.Site.WeeklyReport.changeset(%Plausible.Site.WeeklyReport{}, %{
      site_id: site.id,
      recipients: [conn.assigns[:current_user].email]
    })
    |> Repo.insert!()

    conn
    |> put_flash(:success, "Success! You will receive an email report every Monday going forward")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#email-reports")
  end

  def disable_weekly_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Repo.delete_all(from wr in Plausible.Site.WeeklyReport, where: wr.site_id == ^site.id)

    conn
    |> put_flash(:success, "Success! You will not receive weekly email reports going forward")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#email-reports")
  end

  def add_weekly_report_recipient(conn, %{"website" => website, "recipient" => recipient}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    |> Plausible.Site.WeeklyReport.add_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Succesfully added #{recipient} as a recipient for the weekly report")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#email-reports")
  end

  def remove_weekly_report_recipient(conn, %{"website" => website, "recipient" => recipient}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    |> Plausible.Site.WeeklyReport.remove_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(
      :success,
      "Succesfully removed #{recipient} as a recipient for the weekly report"
    )
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#email-reports")
  end

  def enable_monthly_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Plausible.Site.MonthlyReport.changeset(%Plausible.Site.MonthlyReport{}, %{
      site_id: site.id,
      recipients: [conn.assigns[:current_user].email]
    })
    |> Repo.insert!()

    conn
    |> put_flash(:success, "Success! You will receive an email report every month going forward")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#email-reports")
  end

  def disable_monthly_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Repo.delete_all(from mr in Plausible.Site.MonthlyReport, where: mr.site_id == ^site.id)

    conn
    |> put_flash(:success, "Success! You will not receive monthly email reports going forward")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#email-reports")
  end

  def add_monthly_report_recipient(conn, %{"website" => website, "recipient" => recipient}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    |> Plausible.Site.MonthlyReport.add_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(:success, "Succesfully added #{recipient} as a recipient for the monthly report")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#email-reports")
  end

  def remove_monthly_report_recipient(conn, %{"website" => website, "recipient" => recipient}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    |> Plausible.Site.MonthlyReport.remove_recipient(recipient)
    |> Repo.update!()

    conn
    |> put_flash(
      :success,
      "Succesfully removed #{recipient} as a recipient for the monthly report"
    )
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings#email-reports")
  end

  def new_shared_link(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    changeset = Plausible.Site.SharedLink.changeset(%Plausible.Site.SharedLink{}, %{})

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("new_shared_link.html",
      site: site,
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def create_shared_link(conn, %{"website" => website, "shared_link" => link}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    changes =
      Plausible.Site.SharedLink.changeset(
        %Plausible.Site.SharedLink{
          site_id: site.id,
          slug: Nanoid.generate()
        },
        link
      )

    case Repo.insert(changes) do
      {:ok, _created} ->
        redirect(conn, to: "/#{URI.encode_www_form(site.domain)}/settings#visibility")

      {:error, changeset} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("new_shared_link.html",
          site: site,
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def delete_shared_link(conn, %{"website" => website, "slug" => slug}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Repo.get_by(Plausible.Site.SharedLink, slug: slug)
    |> Repo.delete!()

    redirect(conn, to: "/#{URI.encode_www_form(site.domain)}/settings#visibility")
  end

  def new_custom_domain(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    changeset = Plausible.Site.CustomDomain.changeset(%Plausible.Site.CustomDomain{}, %{})

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("new_custom_domain.html",
      site: site,
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def custom_domain_dns_setup(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:custom_domain)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("custom_domain_dns_setup.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def custom_domain_snippet(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:custom_domain)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("custom_domain_snippet.html",
      site: site,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def add_custom_domain(conn, %{"website" => website, "custom_domain" => domain}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    case Sites.add_custom_domain(site, domain["domain"]) do
      {:ok, _custom_domain} ->
        redirect(conn, to: "/sites/#{URI.encode_www_form(site.domain)}/custom-domains/dns-setup")

      {:error, changeset} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("new_custom_domain.html",
          site: site,
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def delete_custom_domain(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:custom_domain)

    Repo.delete!(site.custom_domain)

    conn
    |> put_flash(:success, "Custom domain deleted succesfully")
    |> redirect(to: "/#{URI.encode_www_form(site.domain)}/settings")
  end

  defp insert_site(user_id, params) do
    site_changeset = Plausible.Site.changeset(%Plausible.Site{}, params)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:site, site_changeset)
    |> Ecto.Multi.run(:site_membership, fn repo, %{site: site} ->
      membership_changeset =
        Plausible.Site.Membership.changeset(%Plausible.Site.Membership{}, %{
          site_id: site.id,
          user_id: user_id
        })

      repo.insert(membership_changeset)
    end)
    |> Repo.transaction()
  end
end
