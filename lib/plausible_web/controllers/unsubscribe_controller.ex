defmodule PlausibleWeb.UnsubscribeController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Site.{WeeklyReport, MonthlyReport}

  def weekly_report(conn, %{"website" => website, "email" => email}) do
    site = Repo.get_by(Plausible.Site, domain: website)

    Repo.get_by(WeeklyReport, site_id: site.id)
    |> WeeklyReport.remove_recipient(email)
    |> Repo.update!

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("success.html", interval: "weekly", site: website, layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def monthly_report(conn, %{"website" => website, "email" => email}) do
    site = Repo.get_by(Plausible.Site, domain: website)

    Repo.get_by(MonthlyReport, site_id: site.id)
    |> MonthlyReport.remove_recipient(email)
    |> Repo.update!

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("success.html", interval: "monthly", site: website, layout: {PlausibleWeb.LayoutView, "focus.html"})
  end
end
