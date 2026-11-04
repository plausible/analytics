defmodule PlausibleWeb.UnsubscribeController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Site.{WeeklyReport, MonthlyReport}

  # capability:begin
  # id: unsubscribe_weekly_report@other
  # action: unsubscribe_weekly_report
  # transport: other
  # entry: GET /sites/:domain/weekly-report/unsubscribe (router.ex scope "/", pipe_through [:browser, :csrf])
  # handler: PlausibleWeb.UnsubscribeController.weekly_report/2
  # credential: [none]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: none
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: Email link; unauthenticated GET that removes ?email from the recipients, so anyone who knows the domain and an address can unsubscribe it
  # capability:end
  def weekly_report(conn, %{"domain" => domain, "email" => email}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
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
      site: site || %{domain: domain}
    )
  end

  def weekly_report(conn, _) do
    render_error(conn, 400)
  end

  # capability:begin
  # id: unsubscribe_monthly_report@other
  # action: unsubscribe_monthly_report
  # transport: other
  # entry: GET /sites/:domain/monthly-report/unsubscribe (router.ex scope "/", pipe_through [:browser, :csrf])
  # handler: PlausibleWeb.UnsubscribeController.monthly_report/2
  # credential: [none]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: []
  # current_role_enforced_by: none
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: []
  # confidence: verified
  # notes: Email link; unauthenticated GET that removes ?email from the recipients, so anyone who knows the domain and an address can unsubscribe it
  # capability:end
  def monthly_report(conn, %{"domain" => domain, "email" => email}) do
    site = Repo.get_by(Plausible.Site, domain: domain)
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
      site: site || %{domain: domain}
    )
  end

  def monthly_report(conn, _) do
    render_error(conn, 400)
  end
end
