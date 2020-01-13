defmodule PlausibleWeb.StatsController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Stats

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

  def csv_export(conn, %{"website" => website}) do
    site = Repo.get_by(Plausible.Site, domain: website)

    if site && current_user_can_access?(conn, site) do
      query = Stats.Query.from(site.timezone, conn.params)
      {plot, _, labels, _} = Stats.calculate_plot(site, query)
      csv_content = Enum.zip(labels, plot)
                    |> Enum.map(fn {k, v} -> [k, v] end)
                    |> (fn data -> [["Date", "Visitors"] | data] end).()
                    |> CSV.encode
                    |> Enum.into([])
                    |> Enum.join()

      filename = "Visitors #{website} #{Timex.format!(query.date_range.first, "{ISOdate} ")} to #{Timex.format!(query.date_range.last, "{ISOdate} ")}.csv"

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_resp(200, csv_content)
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

