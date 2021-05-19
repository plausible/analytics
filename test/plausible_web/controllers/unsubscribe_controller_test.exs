defmodule PlausibleWeb.UnsubscribeControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo

  describe "GET /sites/:website/weekly-report/unsubscribe" do
    test "removes a recipient from the weekly report without them having to log in", %{conn: conn} do
      site = insert(:site)
      insert(:weekly_report, site: site, recipients: ["recipient@email.com"])

      conn =
        get(conn, "/sites/#{site.domain}/weekly-report/unsubscribe?email=recipient@email.com")

      assert html_response(conn, 200) =~ "Unsubscribe successful"

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert report.recipients == []
    end

    test "renders success if site or weekly report does not exist in the database", %{conn: conn} do
      conn =
        get(conn, "/sites/nonexistent.com/weekly-report/unsubscribe?email=recipient@email.com")

      assert html_response(conn, 200) =~ "Unsubscribe successful"
    end
  end

  describe "GET /sites/:website/monthly-report/unsubscribe" do
    test "removes a recipient from the weekly report without them having to log in", %{conn: conn} do
      site = insert(:site)
      insert(:monthly_report, site: site, recipients: ["recipient@email.com"])

      conn =
        get(conn, "/sites/#{site.domain}/monthly-report/unsubscribe?email=recipient@email.com")

      assert html_response(conn, 200) =~ "Unsubscribe successful"

      report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
      assert report.recipients == []
    end

    test "renders success if site or weekly report does not exist in the database", %{conn: conn} do
      conn =
        get(conn, "/sites/nonexistent.com/monthly-report/unsubscribe?email=recipient@email.com")

      assert html_response(conn, 200) =~ "Unsubscribe successful"
    end
  end
end
