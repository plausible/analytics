defmodule PlausibleWeb.UnsubscribeControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo
  use Plausible.Teams.Test

  setup {PlausibleWeb.FirstLaunchPlug.Test, :skip}

  describe "GET /sites/:domain/weekly-report/unsubscribe" do
    test "removes a recipient from the weekly report without them having to log in", %{conn: conn} do
      site = new_site()
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

    test "renders failure if email parameter not provided", %{conn: conn} do
      conn =
        get(conn, "/sites/nonexistent.com/weekly-report/unsubscribe")

      assert html_response(conn, 400) =~ "Bad Request"
    end
  end

  describe "GET /sites/:domain/monthly-report/unsubscribe" do
    test "removes a recipient from the weekly report without them having to log in", %{conn: conn} do
      site = new_site()
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

    test "renders failure if email parameter not provided", %{conn: conn} do
      conn =
        get(conn, "/sites/nonexistent.com/monthly-report/unsubscribe")

      assert html_response(conn, 400) =~ "Bad Request"
    end
  end
end
