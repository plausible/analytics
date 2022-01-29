defmodule Plausible.ImportedTest do
  use PlausibleWeb.ConnCase
  use Timex
  import Plausible.TestUtils

  @utc Timezone.get("UTC")

  describe "Parse and import third party data fetched from Google Analytics" do
    setup [:create_user, :log_in, :create_new_site]

    test "Visitors data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100"],
                     "metrics" => [%{"values" => ["1", "1", "0", "1", "60"]}]
                   },
                   %{
                     "dimensions" => ["2021013100"],
                     "metrics" => [%{"values" => ["1", "1", "1", "1", "60"]}]
                   }
                 ],
                 site.id,
                 "visitors",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&with_imported=true"
        )

      assert %{"plot" => plot, "imported_source" => "Google Analytics"} = json_response(conn, 200)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 2
      assert List.last(plot) == 2
      assert Enum.sum(plot) == 4
    end

    test "Sources data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "Google",
          referrer: "google.com",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          referrer_source: "DuckDuckGo",
          referrer: "duckduckgo.com",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "duckduckgo.com"],
                     "metrics" => [%{"values" => ["1", "1", "0", "60"]}]
                   },
                   %{
                     "dimensions" => ["2021013100", "google.com"],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   }
                 ],
                 site.id,
                 "sources",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=month&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{"name" => "Google", "visitors" => 3},
               %{"name" => "DuckDuckGo", "visitors" => 2}
             ]
    end

    test "UTM mediums data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          utm_medium: "social",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          utm_medium: "social",
          timestamp: ~N[2021-01-01 12:00:00]
        ),
        build(:pageview,
          utm_medium: "email",
          timestamp: ~N[2021-01-01 00:00:00]
        )
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "social"],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   },
                   %{
                     "dimensions" => ["2021010100", "email"],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   }
                 ],
                 site.id,
                 "utm_mediums",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_mediums?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "bounce_rate" => 100.0,
                 "name" => "social",
                 "visit_duration" => 20,
                 "visitors" => 3
               },
               %{
                 "bounce_rate" => 50.0,
                 "name" => "email",
                 "visit_duration" => 50.0,
                 "visitors" => 2
               }
             ]
    end

    test "UTM campaigns data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, utm_campaign: "profile", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, utm_campaign: "august", timestamp: ~N[2021-01-01 00:00:00])
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "profile"],
                     "metrics" => [%{"values" => ["1", "1", "1", "100"]}]
                   },
                   %{
                     "dimensions" => ["2021010100", "august"],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   }
                 ],
                 site.id,
                 "utm_campaigns",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_campaigns?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "august",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 50.0
               },
               %{
                 "name" => "profile",
                 "visitors" => 2,
                 "bounce_rate" => 100.0,
                 "visit_duration" => 50.0
               }
             ]
    end

    test "UTM terms data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, utm_term: "oat milk", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, utm_term: "Sweden", timestamp: ~N[2021-01-01 00:00:00])
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "oat milk"],
                     "metrics" => [%{"values" => ["1", "1", "1", "100"]}]
                   },
                   %{
                     "dimensions" => ["2021010100", "Sweden"],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   }
                 ],
                 site.id,
                 "utm_terms",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_terms?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "Sweden",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 50.0
               },
               %{
                 "name" => "oat milk",
                 "visitors" => 2,
                 "bounce_rate" => 100.0,
                 "visit_duration" => 50.0
               }
             ]
    end
  end
end
