defmodule PlausibleWeb.Api.StatsController.OperatingSystemsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/operating_systems" do
    setup [:create_user, :log_in, :create_site]

    test "returns operating systems by new visitors", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"name" => "Mac", "count" => 2, "percentage" => 67},
               %{"name" => "Android", "count" => 1, "percentage" => 33}
             ]
    end
  end
end
