defmodule Plausible.ImportedTest do
  use PlausibleWeb.ConnCase
  use Timex
  import Plausible.TestUtils

  @user_id 123

  describe "Parse and import third party data fetched from Google Analytics" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "Visitors data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101"],
                     "metrics" => [%{"values" => ["1", "1", "0", "1", "60"]}]
                   },
                   %{
                     "dimensions" => ["20210131"],
                     "metrics" => [%{"values" => ["1", "1", "1", "1", "60"]}]
                   }
                 ],
                 site.id,
                 "imported_visitors"
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

    test "Sources are imported", %{conn: conn, site: site} do
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

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "duckduckgo.com", "organic", "", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "0", "60"]}]
                   },
                   %{
                     "dimensions" => ["20210131", "google.com", "organic", "", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "google.com", "paid", "", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Twitter", "social", "", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   },
                   %{
                     "dimensions" => [
                       "20210131",
                       "A Nice Newsletter",
                       "email",
                       "newsletter",
                       "",
                       ""
                     ],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "(direct)", "(none)", "", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   }
                 ],
                 site.id,
                 "imported_sources"
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/sources?period=month&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{"name" => "Google", "visitors" => 4},
               %{"name" => "DuckDuckGo", "visitors" => 2},
               %{"name" => "A Nice Newsletter", "visitors" => 1},
               %{"name" => "Twitter", "visitors" => 1}
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
        )
      ])

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "Twitter", "social", "", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "(direct)", "(none)", "", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "1", "60"]}]
                   }
                 ],
                 site.id,
                 "imported_sources"
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
               }
             ]
    end

    test "UTM campaigns data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, utm_campaign: "profile", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, utm_campaign: "august", timestamp: ~N[2021-01-01 00:00:00])
      ])

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "Twitter", "social", "profile", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "1", "100"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Gmail", "email", "august", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Gmail", "email", "(not set)", "", ""],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   }
                 ],
                 site.id,
                 "imported_sources"
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

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "Google", "paid", "", "", "oat milk"],
                     "metrics" => [%{"values" => ["1", "1", "1", "100"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Google", "paid", "", "", "Sweden"],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Google", "paid", "", "", "(not set)"],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   }
                 ],
                 site.id,
                 "imported_sources"
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

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "Google", "paid", "", "ad", ""],
                     "metrics" => [%{"values" => ["1", "1", "1", "100"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Google", "paid", "", "blog", ""],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Google", "paid", "", "(not set)", ""],
                     "metrics" => [%{"values" => ["1", "1", "0", "100"]}]
                   }
                 ],
                 site.id,
                 "imported_sources"
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
          hostname: "host-a.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          pathname: "/some-other-page",
          hostname: "host-a.com",
          user_id: @user_id,
          timestamp: ~N[2021-01-01 00:15:00]
        )
      ])

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "host-a.com", "/"],
                     "metrics" => [%{"values" => ["1", "1", "0", "700"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "host-b.com", "/some-other-page"],
                     "metrics" => [%{"values" => ["1", "2", "1", "60"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "host-b.com", "/some-other-page?wat=wot"],
                     "metrics" => [%{"values" => ["1", "1", "0", "60"]}]
                   }
                 ],
                 site.id,
                 "imported_pages"
               )

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "/"],
                     "metrics" => [%{"values" => ["1", "3", "10", "1"]}]
                   }
                 ],
                 site.id,
                 "imported_entry_pages"
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "bounce_rate" => nil,
                 "time_on_page" => 60,
                 "visitors" => 3,
                 "pageviews" => 4,
                 "name" => "/some-other-page"
               },
               %{
                 "bounce_rate" => 25.0,
                 "time_on_page" => 800.0,
                 "visitors" => 2,
                 "pageviews" => 2,
                 "name" => "/"
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

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "host-a.com", "/page2"],
                     "metrics" => [%{"values" => ["2", "4", "0", "10"]}]
                   }
                 ],
                 site.id,
                 "imported_pages"
               )

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "/page2"],
                     "metrics" => [%{"values" => ["2", "3"]}]
                   }
                 ],
                 site.id,
                 "imported_exit_pages"
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

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "EE", "Tartumaa"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "GB", "Midlothian"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   }
                 ],
                 site.id,
                 "imported_locations"
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

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "mobile"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Laptop"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   }
                 ],
                 site.id,
                 "imported_devices"
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

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "User-Agent: Mozilla"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Android Browser"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   }
                 ],
                 site.id,
                 "imported_browsers"
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

    test "OS data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", timestamp: ~N[2021-01-01 00:15:00]),
        build(:pageview, operating_system: "Mac", timestamp: ~N[2021-01-01 00:15:00]),
        build(:pageview, operating_system: "GNU/Linux", timestamp: ~N[2021-01-01 00:15:00])
      ])

      assert :ok =
               Plausible.Imported.from_google_analytics(
                 [
                   %{
                     "dimensions" => ["20210101", "Macintosh"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   },
                   %{
                     "dimensions" => ["20210101", "Linux"],
                     "metrics" => [%{"values" => ["1", "1", "0", "10"]}]
                   }
                 ],
                 site.id,
                 "imported_operating_systems"
               )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/operating-systems?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{"name" => "Mac", "visitors" => 3, "percentage" => 60},
               %{"name" => "GNU/Linux", "visitors" => 2, "percentage" => 40}
             ]
    end
  end
end
