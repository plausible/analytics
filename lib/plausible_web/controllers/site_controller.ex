defmodule PlausibleWeb.SiteController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  plug PlausibleWeb.RequireAccountPlug

  def new(conn, _params) do
    changeset = Plausible.Site.changeset(%Plausible.Site{})
    Plausible.Tracking.event(conn, "New Site: View Form")

    render(conn, "new.html", changeset: changeset)
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

  def add_snippet(conn, %{"website" => website}) do
    site = Plausible.Repo.get_by!(Plausible.Site, domain: website)
    Plausible.Tracking.event(conn, "Site: View Snippet")
    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("snippet.html", site: site)
  end

  def create_site(conn, %{"site" => site_params}) do
    case insert_site(conn.assigns[:current_user].id, site_params) do
      {:ok, %{site: site}} ->
        Plausible.Tracking.event(conn, "New Site: Create")
        redirect(conn, to: "/#{site.domain}/snippet")
      {:error, :site, changeset, _} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
