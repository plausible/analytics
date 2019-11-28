defmodule PlausibleWeb.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  def stats(conn, %{"website" => website}) do
    site = Repo.get_by(Plausible.Site, domain: website)

    if site && current_user_can_access?(conn, site) do
      user = conn.assigns[:current_user]
      if user && Plausible.Billing.needs_to_upgrade?(conn.assigns[:current_user]) do
        redirect(conn, to: "/billing/upgrade")
      else
        if Plausible.Sites.has_pageviews?(site) do
          demo = site.domain == "plausible.io"
          offer_email_report = get_session(conn, site.domain <> "_offer_email_report")

          Plausible.Tracking.event(conn, "Site Analytics: Open", %{demo: demo})

          conn
          |> assign(:skip_plausible_tracking, !demo)
          |> put_session(site.domain <> "_offer_email_report", nil)
          |> render("stats.html",
            site: site,
            has_goals: Plausible.Sites.has_goals?(site),
            title: "Plausible · " <> site.domain,
            offer_email_report: offer_email_report
          )
        else
          conn
          |> assign(:skip_plausible_tracking, true)
          |> render("waiting_first_pageview.html", site: site)
        end
      end
    else
      render_error(conn, 404)
    end
  end

  defp current_user_can_access?(_conn, %Plausible.Site{public: true}) do
    true
  end

  defp current_user_can_access?(conn, site) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Plausible.Sites.is_owner?(user.id, site)
    end
  end
end

