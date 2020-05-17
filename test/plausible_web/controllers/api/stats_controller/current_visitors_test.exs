defmodule PlausibleWeb.Api.StatsController.CurrentVisitorsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/current-visitors" do
    setup [:create_user, :log_in, :create_site]

    test "returns unique users in the last 5 minutes", %{conn: conn, site: site} do
      insert(:pageview, domain: site.domain)
      event2 = insert(:pageview, domain: site.domain, timestamp: Timex.now() |> Timex.shift(minutes: -3))
      insert(:pageview, domain: site.domain, fingerprint: event2.fingerprint, timestamp: Timex.now() |> Timex.shift(minutes: -4))
      insert(:pageview, domain: site.domain, timestamp: Timex.now() |> Timex.shift(minutes: -6))

      conn = get(conn, "/api/stats/#{site.domain}/current-visitors?period=day&date=2019-01-01")

      assert json_response(conn, 200) == 2
    end
  end
end
