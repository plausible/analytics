defmodule PlausibleWeb.Api.StatsController.CountriesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/countries" do
    setup [:create_user, :log_in, :create_site]

    test "returns top countries by new visitors", %{conn: conn, site: site} do
      insert(:pageview, domain: site.domain, country_code: "EE", new_visitor: true, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, domain: site.domain, country_code: "EE", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, domain: site.domain, country_code: "GB", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])

      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "EST", "full_country_name" => "Estonia", "count" => 2, "percentage" => 67},
        %{"name" => "GBR", "full_country_name" => "United Kingdom", "count" => 1, "percentage" => 33},
      ]
    end
  end
end
