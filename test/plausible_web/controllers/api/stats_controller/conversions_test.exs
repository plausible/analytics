defmodule PlausibleWeb.Api.StatsController.ConversionsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/conversions" do
    setup [:create_user, :log_in, :create_site]

    test "returns mixed conversions in ordered by count", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01")

      assert json_response(conn, 200) == [
        %{"name" => "Signup",  "count" => 3},
        %{"name" => "Visit /register", "count" => 2}
      ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_site]

    test "returns only the conversion tha is filtered for", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup"})
      conn = get(conn, "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01&filters=#{filters}")

      assert json_response(conn, 200) == [
        %{"name" => "Signup", "count" => 3},
      ]
    end
  end
end
