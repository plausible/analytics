defmodule Plausible.Stats.TimeoutTest do
  use PlausibleWeb.ConnCase

  describe "fake endpoint" do
    setup [:create_user, :log_in, :create_site]

    test "returns error and captures Sentry report when a query fails with timeout", %{
      test_pid: test_pid,
      conn: conn,
      site: site
    } do
      Plausible.Test.Support.Sentry.setup(test_pid)

      {status, _headers, _body} =
        assert_error_sent(500, fn ->
          get(conn, "/api/stats/#{site.domain}/sentry")
        end)

      assert status == 500

      assert [report] = Sentry.Test.pop_sentry_reports()
      dbg(report)
      # assert report.message.formatted == "traffic_for_site_ids: batch query failed"
      # assert report.extra.batch_size == 3
      # assert report.extra.first_site_id == 1
      # assert report.extra.last_site_id == 3
      # assert is_binary(report.extra.error)
    end
  end
end
