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
        redirect(conn, to: "/#{site.domain}/snippet")
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
    changeset = Plausible.Site.changeset(site, %{})
    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("settings.html", site: site, changeset: changeset)
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

    Repo.delete_all(from sm in "site_memberships", where: sm.site_id == ^site.id)
    Repo.delete_all(from p in "pageviews", where: p.hostname == ^site.domain)

    Repo.delete!(site)

    conn
    |> put_flash(:success, "Site deleted succesfully along with all pageviews")
    |> redirect(to: "/")
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
