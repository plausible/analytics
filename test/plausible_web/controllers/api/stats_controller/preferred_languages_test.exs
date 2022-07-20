defmodule PlausibleWeb.Api.StatsController.PreferredLanguagesTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/preferred-languages" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "returns preferred languages by new visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, preferred_language: "en"),
        build(:pageview, preferred_language: "en"),
        build(:pageview, preferred_language: "es"),
        build(:pageview, preferred_language: "pt")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/preferred-languages?period=day")

      assert json_response(conn, 200) == [
               %{"name" => "English", "percentage" => 50, "visitors" => 2},
               %{"name" => "Portuguese", "percentage" => 25, "visitors" => 1},
               %{"name" => "Spanish", "percentage" => 25, "visitors" => 1}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, preferred_language: "en"),
        build(:pageview, user_id: 2, preferred_language: "en"),
        build(:event, user_id: 1, name: "Signup")
      ])

      filters = Jason.encode!(%{"goal" => "Signup"})

      conn =
        get(conn, "/api/stats/#{site.domain}/preferred-languages?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "name" => "English",
                 "total_visitors" => 2,
                 "visitors" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end
  end
end
