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

    google_search_console_verified = if site.google_auth do
      google_site = Plausible.Google.Api.fetch_site(site.domain, site.google_auth)
      !google_site["error"]
    end

    report = Repo.get_by(Plausible.Site.EmailSettings, site_id: site.id)
    report_changeset = report && Plausible.Site.EmailSettings.changeset(report, %{})

    changeset = Plausible.Site.changeset(site, %{})

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings.html",
      site: site,
      report_changeset: report_changeset,
      google_search_console_verified: google_search_console_verified,
      changeset: changeset
    )
  end


  def update_email_settings(conn, %{"website" => website, "email_settings" => email_settings}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Repo.get_by(Plausible.Site.EmailSettings, site_id: site.id)
    |> Plausible.Site.EmailSettings.changeset(email_settings)
    |> Repo.update!

    conn
    |> put_flash(:success, "Email address saved succesfully")
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

  def enable_email_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)

    Plausible.Site.EmailSettings.changeset(%Plausible.Site.EmailSettings{}, %{
      site_id: site.id,
      email: conn.assigns[:current_user].email
    })
    |> Repo.insert!

    conn
    |> put_flash(:success, "Success! You will receive an email report every Monday going forward")
    |> redirect(to: "/" <> site.domain <> "/settings")
  end

  def disable_email_report(conn, %{"website" => website}) do
    site = Sites.get_for_user!(conn.assigns[:current_user].id, website)
    Repo.delete_all(from es in Plausible.Site.EmailSettings, where: es.site_id == ^site.id)

    conn
    |> put_flash(:success, "Success! You will not receive weekly email reports going forward")
    |> redirect(to: "/" <> site.domain <> "/settings")
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
