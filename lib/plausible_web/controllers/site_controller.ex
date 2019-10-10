defmodule PlausibleWeb.SiteController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Sites

  plug PlausibleWeb.RequireAccountPlug

  def new(conn, _params) do
    changeset = Plausible.Site.changeset(%Plausible.Site{})

    render(conn, "new.html", changeset: changeset, layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def create_site(conn, %{"site" => site_params}) do
    user = conn.assigns[:current_user]

    case insert_site(user.id, site_params) do
      {:ok, %{site: site}} ->
        Plausible.Tracking.event(conn, "New Site: Create", %{domain: site.domain})
        Plausible.Slack.notify("#{user.name} created #{site.domain}")
        conn
        |> put_session(site.domain <> "_offer_email_report", true)
        |> redirect(to: "/#{site.domain}/snippet")
      {:error, :site, changeset, _} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def add_snippet(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("snippet.html", site: site, layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def settings(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
           |> Repo.preload(:google_auth)

    search_console_domains = if site.google_auth do
      Plausible.Google.Api.fetch_verified_properties(site.google_auth)
    end

    weekly_report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    weekly_report_changeset = weekly_report && Plausible.Site.WeeklyReport.changeset(weekly_report, %{})
    monthly_report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    monthly_report_changeset = monthly_report && Plausible.Site.WeeklyReport.changeset(monthly_report, %{})

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings.html",
      site: site,
      weekly_report_changeset: weekly_report_changeset,
      monthly_report_changeset: monthly_report_changeset,
      search_console_domains: search_console_domains,
      changeset: Plausible.Site.changeset(site, %{})
    )
  end

  def update_google_auth(conn, %{"website" => website, "google_auth" => attrs}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
           |> Repo.preload(:google_auth)

    Plausible.Site.GoogleAuth.set_property(site.google_auth, attrs)
    |> Repo.update!

    conn
    |> put_flash(:success, "Google integration saved succesfully")
    |> redirect(to: "/#{site.domain}/settings")
  end

  def update_settings(conn, %{"website" => website, "site" => site_params}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    changeset =  site |> Plausible.Site.changeset(site_params)
    res = changeset |> Repo.update

    case res do
      {:ok, site} ->
        conn
        |> put_flash(:success, "Site settings saved succesfully")
        |> redirect(to: "/#{site.domain}/settings")
      {:error, changeset} ->
        render("settings.html", site: site, changeset: changeset)
    end
  end

  def delete_site(conn, %{"website" => website}) do
    site =
      Sites.get_for_user!(conn.assigns[:current_user].id, website)
      |> Repo.preload(:google_auth)

    Repo.delete_all(from sm in "site_memberships", where: sm.site_id == ^site.id)
    Repo.delete_all(from p in "pageviews", where: p.hostname == ^site.domain)

    if site.google_auth do
      Repo.delete!(site.google_auth)
    end
    Repo.delete!(site)

    conn
    |> put_flash(:success, "Site deleted succesfully along with all pageviews")
    |> redirect(to: "/")
  end

  def make_public(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    |> Plausible.Site.make_public
    |> Repo.update!

    conn
    |> put_flash(:success, "Congrats! Stats for #{site.domain} are now public.")
    |> redirect(to: "/" <> site.domain <> "/settings")
  end

  def make_private(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    |> Plausible.Site.make_private
    |> Repo.update!

    conn
    |> put_flash(:success, "Stats for #{site.domain} are now private.")
    |> redirect(to: "/" <> site.domain <> "/settings")
  end

  def enable_weekly_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Plausible.Site.WeeklyReport.changeset(%Plausible.Site.WeeklyReport{}, %{
      site_id: site.id,
      email: conn.assigns[:current_user].email
    })
    |> Repo.insert!

    conn
    |> put_flash(:success, "Success! You will receive an email report every Monday going forward")
    |> redirect(to: "/" <> site.domain <> "/settings")
  end

  def disable_weekly_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Repo.delete_all(from wr in Plausible.Site.WeeklyReport, where: wr.site_id == ^site.id)

    conn
    |> put_flash(:success, "Success! You will not receive weekly email reports going forward")
    |> redirect(to: "/" <> site.domain <> "/settings")
  end

  def update_weekly_settings(conn, %{"website" => website, "weekly_report" => weekly_report}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    |> Plausible.Site.WeeklyReport.changeset(weekly_report)
    |> Repo.update!

    conn
    |> put_flash(:success, "Email address saved succesfully")
    |> redirect(to: "/#{site.domain}/settings")
  end

  def enable_monthly_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Plausible.Site.MonthlyReport.changeset(%Plausible.Site.MonthlyReport{}, %{
      site_id: site.id,
      email: conn.assigns[:current_user].email
    })
    |> Repo.insert!

    conn
    |> put_flash(:success, "Success! You will receive an email report every month going forward")
    |> redirect(to: "/" <> site.domain <> "/settings")
  end

  def disable_monthly_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Repo.delete_all(from mr in Plausible.Site.MonthlyReport, where: mr.site_id == ^site.id)

    conn
    |> put_flash(:success, "Success! You will not receive monthly email reports going forward")
    |> redirect(to: "/" <> site.domain <> "/settings")
  end

  def update_monthly_settings(conn, %{"website" => website, "monthly_report" => monthly_report}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    |> Plausible.Site.WeeklyReport.changeset(monthly_report)
    |> Repo.update!

    conn
    |> put_flash(:success, "Email address saved succesfully")
    |> redirect(to: "/#{site.domain}/settings")
  end

  def google_settings(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
           |> Repo.preload(:google_auth)

    verified_domains = Plausible.Google.Api.fetch_verified_properties(site.google_auth)

    render(conn,
      "google_settings.html",
      site: site,
      verified_domains: verified_domains,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  defp insert_site(user_id, params) do
    site_changeset = Plausible.Site.changeset(%Plausible.Site{}, params)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:site, site_changeset)
    |>  Ecto.Multi.run(:site_membership, fn repo, %{site: site} ->
      membership_changeset = Plausible.Site.Membership.changeset(%Plausible.Site.Membership{}, %{
        site_id: site.id,
        user_id: user_id
      })
      repo.insert(membership_changeset)
    end)
    |> Repo.transaction
  end

end
