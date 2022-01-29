defmodule Plausible.ImportedTest do
  use PlausibleWeb.ConnCase
  use Timex
  import Plausible.TestUtils

  @utc Timezone.get("UTC")
  @user_id 123

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

    test "UTM contents data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, utm_content: "ad", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, utm_content: "blog", timestamp: ~N[2021-01-01 00:00:00])
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "ad"],
                     "metrics" => [%{"values" => ["1", "1", "1", "100"]}]
                   },
                   %{
                     "dimensions" => ["2021010100", "blog"],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   }
                 ],
                 site.id,
                 "utm_contents",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/utm_contents?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "blog",
                 "visitors" => 2,
                 "bounce_rate" => 50.0,
                 "visit_duration" => 50.0
               },
               %{
                 "name" => "ad",
                 "visitors" => 2,
                 "bounce_rate" => 100.0,
                 "visit_duration" => 50.0
               }
             ]
    end

    test "Page event data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/some-other-page",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "/"],
                     "metrics" => [%{"values" => ["1", "1", "700"]}]
                   },
                   %{
                     "dimensions" => ["2021010100", "/some-other-page"],
                     "metrics" => [%{"values" => ["1", "1", "60"]}]
                   }
                 ],
                 site.id,
                 "pages",
                 @utc
               )

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "/"],
                     "metrics" => [%{"values" => ["1", "3", "10", "1"]}]
                   }
                 ],
                 site.id,
                 "entry_pages",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "bounce_rate" => 40.0,
                 "time_on_page" => 800.0,
                 "visitors" => 3,
                 "pageviews" => 3,
                 "name" => "/"
               },
               %{
                 "bounce_rate" => nil,
                 "time_on_page" => 60,
                 "visitors" => 2,
                 "pageviews" => 2,
                 "name" => "/some-other-page"
               }
             ]
    end

    test "Exit page event data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page1",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/page2",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "/page2"],
                     "metrics" => [%{"values" => ["2", "4", "10"]}]
                   }
                 ],
                 site.id,
                 "pages",
                 @utc
               )

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "/page2"],
                     "metrics" => [%{"values" => ["2", "3"]}]
                   }
                 ],
                 site.id,
                 "exit_pages",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/exit-pages?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/page2",
                 "unique_exits" => 3,
                 "total_exits" => 4,
                 "exit_rate" => 80.0
               },
               %{"name" => "/page1", "unique_exits" => 2, "total_exits" => 2, "exit_rate" => 66}
             ]
    end

    test "Location data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          country_code: "EE",
          timestamp: ~N[2021-01-01 00:15:00]
        ),
        build(:pageview,
          country_code: "GB",
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "EE", "Tartumaa"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   },
                   %{
                     "dimensions" => ["2021010100", "GB", "Midlothian"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   }
                 ],
                 site.id,
                 "locations",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/countries?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "visitors" => 3,
                 "percentage" => 60
               },
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 2,
                 "percentage" => 40
               }
             ]
    end

    test "Devices data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop", timestamp: ~N[2021-01-01 00:15:00]),
        build(:pageview, screen_size: "Desktop", timestamp: ~N[2021-01-01 00:15:00]),
        build(:pageview, screen_size: "Laptop", timestamp: ~N[2021-01-01 00:15:00])
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "mobile"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   },
                   %{
                     "dimensions" => ["2021010100", "Laptop"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   }
                 ],
                 site.id,
                 "devices",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/screen-sizes?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 2, "percentage" => 40},
               %{"name" => "Laptop", "visitors" => 2, "percentage" => 40},
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 20}
             ]
    end

    test "Browsers data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-01 00:15:00]),
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:15:00])
      ])

      assert {:ok, _} =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["2021010100", "User-Agent: Mozilla"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   },
                   %{
                     "dimensions" => ["2021010100", "Android Browser"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   }
                 ],
                 site.id,
                 "browsers",
                 @utc
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/browsers?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{"name" => "Firefox", "visitors" => 2, "percentage" => 50},
               %{"name" => "Mobile App", "visitors" => 1, "percentage" => 25},
               %{"name" => "Chrome", "visitors" => 1, "percentage" => 25}
             ]
    end
  end
end
