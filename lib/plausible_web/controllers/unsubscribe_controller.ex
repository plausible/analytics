defmodule PlausibleWeb.UnsubscribeController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Site.{WeeklyReport, MonthlyReport}

  def weekly_report(conn, %{"website" => website, "email" => email}) do
    site = Repo.get_by(Plausible.Site, domain: website)
    weekly_report = site && Repo.get_by(WeeklyReport, site_id: site.id)

    if weekly_report do
      weekly_report
      |> WeeklyReport.remove_recipient(email)
      |> Repo.update!()
    end

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("success.html",
      interval: "weekly",
      site: site || %{domain: website}
    )
  end

  def weekly_report(conn, _) do
    render_error(conn, 400)
  end

  def monthly_report(conn, %{"website" => website, "email" => email}) do
    site = Repo.get_by(Plausible.Site, domain: website)
    monthly_report = site && Repo.get_by(MonthlyReport, site_id: site.id)

    if monthly_report do
      monthly_report
      |> MonthlyReport.remove_recipient(email)
      |> Repo.update!()
    end

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("success.html",
      interval: "monthly",
      site: site || %{domain: website}
    )
  end

  def monthly_report(conn, _) do
    render_error(conn, 400)
  end
end
