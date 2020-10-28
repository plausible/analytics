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
               %{"name" => "Signup", "count" => 3, "total_count" => 3, "meta_keys" => ["variant"]},
               %{"name" => "Visit /register", "count" => 2, "total_count" => 2, "meta_keys" => nil}
             ]
    end
  end

  describe "GET /api/stats/:domain/conversions - with goal filter" do
    setup [:create_user, :log_in, :create_site]

    test "returns only the conversion tha is filtered for", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, page_path: "/register"})
      insert(:goal, %{domain: site.domain, event_name: "Signup"})

      filters = Jason.encode!(%{goal: "Signup"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/conversions?period=day&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"name" => "Signup", "count" => 3, "total_count" => 3, "meta_keys" => ["variant"]}
             ]
    end
  end

  describe "GET /api/stats/:domain/meta-breakdown/:key" do
    setup [:create_user, :log_in, :create_site]

    test "returns metadata breakdown for goal", %{conn: conn, site: site} do
      insert(:goal, %{domain: site.domain, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup"})
      meta_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/meta-breakdown/#{meta_key}?period=day&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
        %{"count" => 2, "name" => "B", "total_count" => 2},
        %{"count" => 1, "name" => "A", "total_count" => 1}
      ]
    end
  end
end
