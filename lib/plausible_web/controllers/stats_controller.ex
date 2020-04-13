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

          conn
          |> assign(:skip_plausible_tracking, !demo)
          |> remove_email_report_banner(site)
          |> put_resp_header("x-robots-tag", "noindex")
          |> render("stats.html",
            site: site,
            has_goals: Plausible.Sites.has_goals?(site),
            title: "Plausible · " <> site.domain,
            offer_email_report: offer_email_report,
            demo: demo
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

  def shared_link(conn, %{"slug" => slug}) do
    shared_link = Repo.get_by(Plausible.Site.SharedLink, slug: slug)
                  |> Repo.preload(:site)

    if shared_link do
      if shared_link.password_hash do
        render(conn, "shared_link_password.html", link: shared_link, layout: {PlausibleWeb.LayoutView, "focus.html"})
      else
        shared_link_auth_success(conn, shared_link)
      end
    else
      render_error(conn, 404)
    end
  end

  def authenticate_shared_link(conn, %{"slug" => slug, "password" => password}) do
    shared_link = Repo.get_by(Plausible.Site.SharedLink, slug: slug)
                  |> Repo.preload(:site)

    if shared_link do
      if Plausible.Auth.Password.match?(password, shared_link.password_hash) do
        shared_link_auth_success(conn, shared_link)
      else
        render(conn, "shared_link_password.html", link: shared_link, error: "Incorrect password. Please try again.", layout: {PlausibleWeb.LayoutView, "focus.html"})
      end
    else
      render_error(conn, 404)
    end
  end

  defp shared_link_auth_success(conn, shared_link) do
    site_session_key = "authorized_site__" <> shared_link.site.domain

    conn
    |> put_session(site_session_key, %{
      id: shared_link.site.id,
      domain: shared_link.site.domain,
      timezone: shared_link.site.timezone,
      valid_until: Timex.now() |> Timex.shift(minutes: 30) |> DateTime.to_unix()
    })
    |> redirect(to: "/#{shared_link.site.domain}")
  end

  defp current_user_can_access?(_conn, %Plausible.Site{public: true}) do
    true
  end

  defp current_user_can_access?(conn, site) do
    site_session_key = "authorized_site__" <> site.domain
    site_session = get_session(conn, site_session_key)
    valid_site_session = site_session && site_session[:valid_until] > DateTime.to_unix(Timex.now())

    valid_site_session || current_user_is_owner?(conn, site)
  end

  defp current_user_is_owner?(conn, site) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> Plausible.Sites.is_owner?(user.id, site)
    end
  end

  defp remove_email_report_banner(conn, site) do
    if conn.assigns[:current_user] do
      put_session(conn, site.domain <> "_offer_email_report", nil)
    else
      conn
    end
  end
end

