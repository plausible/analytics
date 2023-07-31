defmodule Plausible.ImportedTest do
  use PlausibleWeb.ConnCase
  use Timex

  @user_id 123

  defp import_data(ga_data, site_id, table_name) do
    ga_data
    |> Plausible.Imported.from_google_analytics(site_id, table_name)
    |> then(&Plausible.Google.Buffer.insert_all(table_name, &1))
  end

  describe "Parse and import third party data fetched from Google Analytics" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "Visitors data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      import_data(
        [
          %{
            dimensions: %{"ga:date" => "20210101"},
            metrics: %{
              "ga:users" => "1",
              "ga:pageviews" => "1",
              "ga:bounces" => "0",
              "ga:sessions" => "1",
              "ga:sessionDuration" => "60"
            }
          },
          %{
            dimensions: %{"ga:date" => "20210131"},
            metrics: %{
              "ga:users" => "1",
              "ga:pageviews" => "1",
              "ga:bounces" => "0",
              "ga:sessions" => "1",
              "ga:sessionDuration" => "60"
            }
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

    test "returns data grouped by week", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      import_data(
        [
          %{
            dimensions: %{"ga:date" => "20210101"},
            metrics: %{
              "ga:users" => "1",
              "ga:pageviews" => "1",
              "ga:bounces" => "0",
              "ga:sessions" => "1",
              "ga:sessionDuration" => "60"
            }
          },
          %{
            dimensions: %{"ga:date" => "20210131"},
            metrics: %{
              "ga:users" => "1",
              "ga:pageviews" => "1",
              "ga:bounces" => "0",
              "ga:sessions" => "1",
              "ga:sessionDuration" => "60"
            }
          }
        ],
        site.id,
        "imported_visitors"
      )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&with_imported=true&interval=week"
        )

      assert %{"plot" => plot, "imported_source" => "Google Analytics"} = json_response(conn, 200)
      assert Enum.count(plot) == 5
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

      import_data(
        [
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "organic",
              "ga:source" => "duckduckgo.com"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210131",
              "ga:keyword" => "",
              "ga:medium" => "organic",
              "ga:source" => "google.com"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "paid",
              "ga:source" => "google.com"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "social",
              "ga:source" => "Twitter"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "newsletter",
              "ga:date" => "20210131",
              "ga:keyword" => "",
              "ga:medium" => "email",
              "ga:source" => "A Nice Newsletter"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "(none)",
              "ga:source" => "(direct)"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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

      assert conn |> json_response(200) |> Enum.sort() == [
               %{"name" => "A Nice Newsletter", "visitors" => 1},
               %{"name" => "Direct / None", "visitors" => 1},
               %{"name" => "DuckDuckGo", "visitors" => 2},
               %{"name" => "Google", "visitors" => 4},
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

      import_data(
        [
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "social",
              "ga:source" => "Twitter"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "(none)",
              "ga:source" => "(direct)"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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
               },
               %{
                 "bounce_rate" => 100.0,
                 "name" => "Direct / None",
                 "visit_duration" => 60.0,
                 "visitors" => 1
               }
             ]
    end

    test "UTM campaigns data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, utm_campaign: "profile", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, utm_campaign: "august", timestamp: ~N[2021-01-01 00:00:00])
      ])

      import_data(
        [
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "profile",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "social",
              "ga:source" => "Twitter"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "august",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "email",
              "ga:source" => "Gmail"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "(not set)",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "email",
              "ga:source" => "Gmail"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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
               },
               %{
                 "bounce_rate" => 0.0,
                 "name" => "Direct / None",
                 "visit_duration" => 100.0,
                 "visitors" => 1
               }
             ]
    end

    test "UTM terms data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, utm_term: "oat milk", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, utm_term: "Sweden", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, utm_term: "Sweden", timestamp: ~N[2021-01-01 00:00:00])
      ])

      import_data(
        [
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "oat milk",
              "ga:medium" => "paid",
              "ga:source" => "Google"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "Sweden",
              "ga:medium" => "paid",
              "ga:source" => "Google"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "(not set)",
              "ga:medium" => "paid",
              "ga:source" => "Google"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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
                 "visitors" => 3,
                 "bounce_rate" => 67.0,
                 "visit_duration" => 33.3
               },
               %{
                 "name" => "oat milk",
                 "visitors" => 2,
                 "bounce_rate" => 100.0,
                 "visit_duration" => 50.0
               },
               %{
                 "bounce_rate" => 0.0,
                 "name" => "Direct / None",
                 "visit_duration" => 100.0,
                 "visitors" => 1
               }
             ]
    end

    test "UTM contents data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, utm_content: "ad", timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, utm_content: "blog", timestamp: ~N[2021-01-01 00:00:00])
      ])

      import_data(
        [
          %{
            dimensions: %{
              "ga:adContent" => "ad",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "paid",
              "ga:source" => "Google"
            },
            metrics: %{
              "ga:bounces" => "1",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "blog",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "paid",
              "ga:source" => "Google"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:adContent" => "(not set)",
              "ga:campaign" => "",
              "ga:date" => "20210101",
              "ga:keyword" => "",
              "ga:medium" => "paid",
              "ga:source" => "Google"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "100",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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
               },
               %{
                 "bounce_rate" => 0.0,
                 "name" => "Direct / None",
                 "visit_duration" => 100.0,
                 "visitors" => 1
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

      import_data(
        [
          %{
            dimensions: %{
              "ga:date" => "20210101",
              "ga:hostname" => "host-a.com",
              "ga:pagePath" => "/"
            },
            metrics: %{
              "ga:exits" => "0",
              "ga:pageviews" => "1",
              "ga:timeOnPage" => "700",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:date" => "20210101",
              "ga:hostname" => "host-b.com",
              "ga:pagePath" => "/some-other-page"
            },
            metrics: %{
              "ga:exits" => "1",
              "ga:pageviews" => "2",
              "ga:timeOnPage" => "60",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:date" => "20210101",
              "ga:hostname" => "host-b.com",
              "ga:pagePath" => "/some-other-page?wat=wot"
            },
            metrics: %{
              "ga:exits" => "0",
              "ga:pageviews" => "1",
              "ga:timeOnPage" => "60",
              "ga:users" => "1"
            }
          }
        ],
        site.id,
        "imported_pages"
      )

      import_data(
        [
          %{
            dimensions: %{"ga:date" => "20210101", "ga:landingPagePath" => "/"},
            metrics: %{
              "ga:bounces" => "1",
              "ga:entrances" => "3",
              "ga:sessionDuration" => "10",
              "ga:users" => "1"
            }
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

      import_data(
        [
          %{
            dimensions: %{
              "ga:date" => "20210101",
              "ga:hostname" => "host-a.com",
              "ga:pagePath" => "/page2"
            },
            metrics: %{
              "ga:exits" => "0",
              "ga:pageviews" => "4",
              "ga:timeOnPage" => "10",
              "ga:users" => "2"
            }
          }
        ],
        site.id,
        "imported_pages"
      )

      import_data(
        [
          %{
            dimensions: %{"ga:date" => "20210101", "ga:exitPagePath" => "/page2"},
            metrics: %{"ga:exits" => "3", "ga:users" => "2"}
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
                 "visitors" => 3,
                 "visits" => 4,
                 "exit_rate" => 80.0
               },
               %{"name" => "/page1", "visitors" => 2, "visits" => 2, "exit_rate" => 66}
             ]
    end

    test "imports city data from Google Analytics", %{conn: conn, site: site} do
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

      import_data(
        [
          %{
            dimensions: %{
              "ga:countryIsoCode" => "EE",
              "ga:city" => "Tartu",
              "ga:date" => "20210101",
              "ga:regionIsoCode" => "Tartumaa"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:countryIsoCode" => "GB",
              "ga:city" => "Edinburgh",
              "ga:date" => "20210101",
              "ga:regionIsoCode" => "Midlothian"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          }
        ],
        site.id,
        "imported_locations"
      )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/cities?period=day&date=2021-01-01&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{"code" => 588_335, "name" => "Tartu", "visitors" => 1, "country_flag" => "🇪🇪"},
               %{
                 "code" => 2_650_225,
                 "name" => "Edinburgh",
                 "visitors" => 1,
                 "country_flag" => "🇬🇧"
               }
             ]
    end

    test "imports country data from Google Analytics", %{conn: conn, site: site} do
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
        ),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 2)
      ])

      import_data(
        [
          %{
            dimensions: %{
              "ga:countryIsoCode" => "EE",
              "ga:city" => "Tartu",
              "ga:date" => "20210101",
              "ga:regionIsoCode" => "Tartumaa"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{
              "ga:countryIsoCode" => "GB",
              "ga:city" => "Edinburgh",
              "ga:date" => "20210101",
              "ga:regionIsoCode" => "Midlothian"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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
        build(:pageview, screen_size: "Laptop", timestamp: ~N[2021-01-01 00:15:00]),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 2)
      ])

      import_data(
        [
          %{
            dimensions: %{"ga:date" => "20210101", "ga:deviceCategory" => "mobile"},
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{"ga:date" => "20210101", "ga:deviceCategory" => "Laptop"},
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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
        build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:15:00]),
        build(:imported_visitors, visitors: 2, date: ~D[2021-01-01])
      ])

      import_data(
        [
          %{
            dimensions: %{
              "ga:browser" => "User-Agent: Mozilla",
              "ga:date" => "20210101"
            },
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{"ga:browser" => "Android Browser", "ga:date" => "20210101"},
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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

      assert stats = json_response(conn, 200)
      assert length(stats) == 3
      assert %{"name" => "Firefox", "visitors" => 2, "percentage" => 50.0} in stats
      assert %{"name" => "Mobile App", "visitors" => 1, "percentage" => 25.0} in stats
      assert %{"name" => "Chrome", "visitors" => 1, "percentage" => 25.0} in stats
    end

    test "OS data imported from Google Analytics", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, operating_system: "Mac", timestamp: ~N[2021-01-01 00:15:00]),
        build(:pageview, operating_system: "Mac", timestamp: ~N[2021-01-01 00:15:00]),
        build(:pageview, operating_system: "GNU/Linux", timestamp: ~N[2021-01-01 00:15:00]),
        build(:imported_visitors, date: ~D[2021-01-01], visitors: 2)
      ])

      import_data(
        [
          %{
            dimensions: %{"ga:date" => "20210101", "ga:operatingSystem" => "Macintosh"},
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{"ga:date" => "20210101", "ga:operatingSystem" => "Linux"},
            metrics: %{
              "ga:bounces" => "0",
              "ga:sessionDuration" => "10",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
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

    test "Can import visit duration with scientific notation", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
      ])

      import_data(
        [
          %{
            dimensions: %{"ga:date" => "20210101"},
            metrics: %{
              "ga:bounces" => "0",
              "ga:pageviews" => "1",
              "ga:sessionDuration" => "1.391607E7",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          },
          %{
            dimensions: %{"ga:date" => "20210131"},
            metrics: %{
              "ga:bounces" => "1",
              "ga:pageviews" => "1",
              "ga:sessionDuration" => "60",
              "ga:sessions" => "1",
              "ga:users" => "1"
            }
          }
        ],
        site.id,
        "imported_visitors"
      )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&date=2021-01-01&with_imported=true"
        )

      assert %{"top_stats" => top_stats} = json_response(conn, 200)

      visit_duration = Enum.find(top_stats, fn stat -> stat["name"] == "Visit duration" end)

      assert visit_duration["value"] == 3_479_033
    end

    test "skips empty dates from import", %{conn: conn, site: site} do
      import_data(
        [
          %{
            dimensions: %{"ga:date" => "20210101"},
            metrics: %{
              "ga:users" => "1",
              "ga:pageviews" => "1",
              "ga:bounces" => "0",
              "ga:sessions" => "1",
              "ga:sessionDuration" => "60"
            }
          },
          %{
            dimensions: %{"ga:date" => "(other)"},
            metrics: %{
              "ga:users" => "1",
              "ga:pageviews" => "1",
              "ga:bounces" => "0",
              "ga:sessions" => "1",
              "ga:sessionDuration" => "60"
            }
          }
        ],
        site.id,
        "imported_visitors"
      )

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?period=month&date=2021-01-01&with_imported=true"
        )

      assert %{
               "top_stats" => [
                 %{"name" => "Unique visitors", "value" => 1},
                 %{"name" => "Total visits", "value" => 1},
                 %{"name" => "Total pageviews", "value" => 1},
                 %{"name" => "Views per visit", "value" => 0.0},
                 %{"name" => "Bounce rate", "value" => 0},
                 %{"name" => "Visit duration", "value" => 60}
               ]
             } = json_response(conn, 200)
    end
  end
end
