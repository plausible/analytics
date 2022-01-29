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
  end
end
