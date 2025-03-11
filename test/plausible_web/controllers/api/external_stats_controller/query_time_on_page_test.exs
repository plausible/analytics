defmodule PlausibleWeb.Api.ExternalStatsController.QueryTimeOnPageTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key, :create_site_import]

  test "aggregated time_on_page metric based on engagement data", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/blog",
        timestamp: ~N[2021-01-01 00:10:00],
        engagement_time: 120_000
      ),
      build(:engagement,
        user_id: 12,
        pathname: "/blog",
        timestamp: ~N[2021-01-01 00:11:00],
        engagement_time: 20_000
      ),
      build(:pageview, user_id: 13, pathname: "/blog", timestamp: ~N[2021-01-01 00:10:00]),
      build(:engagement,
        user_id: 13,
        pathname: "/blog",
        timestamp: ~N[2021-01-01 00:10:00],
        engagement_time: 60_000
      )
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["time_on_page"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "include" => %{"imports" => true}
      })

    assert_matches %{
                     "results" => [
                       %{"dimensions" => ["/blog"], "metrics" => [100]}
                     ],
                     "meta" =>
                       ^strict_map(%{
                         "imports_included" => true
                       })
                   } = json_response(conn, 200)
  end

  test "aggregated time_on_page metric with imported data", %{
    conn: conn,
    site: site,
    site_import: site_import
  } do
    populate_stats(site, site_import.id, [
      build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/blog",
        timestamp: ~N[2021-01-01 00:10:00],
        engagement_time: 120_000
      ),
      build(:imported_pages,
        page: "/blog",
        date: ~D[2021-01-01],
        visitors: 9,
        total_time_on_page: 9 * 20,
        total_time_on_page_visits: 9
      )
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["time_on_page"],
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "include" => %{"imports" => true}
      })

    assert_matches %{
                     "results" => [
                       %{"dimensions" => ["/blog"], "metrics" => [30]}
                     ],
                     "meta" =>
                       ^strict_map(%{
                         "imports_included" => true
                       })
                   } = json_response(conn, 200)
  end

  test "time_on_page time series", %{conn: conn, site: site, site_import: site_import} do
    populate_stats(site, site_import.id, [
      build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-01 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/",
        timestamp: ~N[2021-01-01 00:03:00],
        engagement_time: 100_000
      ),
      build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-02 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/",
        timestamp: ~N[2021-01-02 00:03:00],
        engagement_time: 100_000
      ),
      build(:pageview, user_id: 13, pathname: "/", timestamp: ~N[2021-01-02 00:00:00]),
      build(:engagement,
        user_id: 13,
        pathname: "/",
        timestamp: ~N[2021-01-02 00:10:00],
        engagement_time: 300_000
      ),
      build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-03 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/",
        timestamp: ~N[2021-01-03 00:03:00],
        engagement_time: 100_000
      ),
      build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-04 00:00:00]),
      build(:engagement,
        user_id: 12,
        pathname: "/",
        timestamp: ~N[2021-01-04 00:03:00],
        engagement_time: 100_000
      ),
      build(:imported_pages,
        page: "/blog",
        date: ~D[2021-01-01],
        visitors: 9,
        total_time_on_page: 9 * 20,
        total_time_on_page_visits: 9
      )
    ])

    conn =
      post(conn, "/api/v2/query-internal-test", %{
        "site_id" => site.domain,
        "metrics" => ["time_on_page"],
        "date_range" => ["2021-01-01", "2021-01-04"],
        "dimensions" => ["time:day", "event:page"],
        "include" => %{"imports" => true}
      })

    assert_matches %{
                     "results" => [
                       %{"dimensions" => ["2021-01-01", "/"], "metrics" => [100]},
                       %{"dimensions" => ["2021-01-01", "/blog"], "metrics" => [20]},
                       %{"dimensions" => ["2021-01-02", "/"], "metrics" => [200]},
                       %{"dimensions" => ["2021-01-03", "/"], "metrics" => [100]},
                       %{"dimensions" => ["2021-01-04", "/"], "metrics" => [100]}
                     ],
                     "meta" =>
                       ^strict_map(%{
                         "imports_included" => true
                       })
                   } = json_response(conn, 200)
  end

  describe "include.legacy_time_on_page_cutoff" do
    setup %{site: site, site_import: site_import} = context do
      populate_stats(site, site_import.id, [
        build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:02:00],
          engagement_time: 100_000
        ),
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:02:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:05:00],
          engagement_time: 100_000
        ),
        build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-01 00:05:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:10:00],
          engagement_time: 100_000
        ),
        build(:pageview, user_id: 12, pathname: "/blog", timestamp: ~N[2021-01-01 00:10:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 00:15:00],
          engagement_time: 100_000
        ),
        build(:pageview, user_id: 13, pathname: "/pricing", timestamp: ~N[2021-01-02 01:00:00]),
        build(:engagement,
          user_id: 13,
          pathname: "/pricing",
          timestamp: ~N[2021-01-02 01:02:00],
          engagement_time: 30_000
        ),
        build(:pageview, user_id: 14, pathname: "/", timestamp: ~N[2021-01-02 01:00:00]),
        build(:engagement,
          user_id: 14,
          pathname: "/",
          timestamp: ~N[2021-01-02 01:02:00],
          engagement_time: 30_000
        ),
        build(:imported_pages,
          page: "/blog",
          date: ~D[2021-01-01],
          visitors: 9,
          total_time_on_page: 9 * 20,
          total_time_on_page_visits: 9
        )
      ])

      context
    end

    test "breakdown with cutoff being before data (new time-on-page query used)", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "include" => %{
            "legacy_time_on_page_cutoff" => "1970-01-01T00:00:00Z",
            "imports" => true
          }
        })

      assert_matches %{
                       "results" => [
                         %{"dimensions" => ["/"], "metrics" => [115]},
                         # (2 * 100s + 9 * 20s) / 10 = 38
                         %{"dimensions" => ["/blog"], "metrics" => [38]},
                         %{"dimensions" => ["/pricing"], "metrics" => [30]}
                       ],
                       "meta" =>
                         ^strict_map(%{
                           "imports_included" => true
                         })
                     } = json_response(conn, 200)
    end

    test "breakdown with cutoff being after data (legacy query used)", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "include" => %{
            "legacy_time_on_page_cutoff" => "2021-01-05T00:00:00Z",
            "imports" => true
          }
        })

      assert_matches %{
                       "results" => [
                         %{"dimensions" => ["/"], "metrics" => [420]},
                         %{"dimensions" => ["/blog"], "metrics" => [180]},
                         %{"dimensions" => ["/pricing"], "metrics" => [nil]}
                       ],
                       "meta" =>
                         ^strict_map(%{
                           "imports_included" => true,
                           "metric_warnings" => %{
                             "time_on_page" => %{
                               "code" => "legacy_time_on_page_used",
                               "message" =>
                                 "Contains less accurate legacy time-on-page data up to 2021-01-05 00:00:00"
                             }
                           }
                         })
                     } = json_response(conn, 200)
    end

    test "breakdown with cutoff being mid-data (two queries joined)", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "include" => %{
            "legacy_time_on_page_cutoff" => "2021-01-02T00:00:00Z",
            "imports" => true
          }
        })

      assert_matches %{
                       "results" => [
                         %{"dimensions" => ["/"], "metrics" => [225]},
                         %{"dimensions" => ["/blog"], "metrics" => [180]},
                         %{"dimensions" => ["/pricing"], "metrics" => [30]}
                       ],
                       "meta" =>
                         ^strict_map(%{
                           "imports_included" => true,
                           "metric_warnings" => %{
                             "time_on_page" => %{
                               "code" => "legacy_time_on_page_used",
                               "message" =>
                                 "Contains less accurate legacy time-on-page data up to 2021-01-02 00:00:00"
                             }
                           }
                         })
                     } = json_response(conn, 200)
    end

    test "breakdown with cutoff being mid-data (two queries joined), no imports", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "include" => %{
            "legacy_time_on_page_cutoff" => "2021-01-02T00:00:00Z"
          }
        })

      assert_matches %{
                       "results" => [
                         %{"dimensions" => ["/"], "metrics" => [225]},
                         %{"dimensions" => ["/blog"], "metrics" => [180]},
                         %{"dimensions" => ["/pricing"], "metrics" => [30]}
                       ],
                       "meta" =>
                         ^strict_map(%{
                           "metric_warnings" => %{
                             "time_on_page" => %{
                               "code" => "legacy_time_on_page_used",
                               "message" =>
                                 "Contains less accurate legacy time-on-page data up to 2021-01-02 00:00:00"
                             }
                           }
                         })
                     } = json_response(conn, 200)
    end

    test "aggregation with cutoff being after data (legacy query used)", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => "all",
          "filters" => [["is", "event:page", ["/blog"]]],
          "include" => %{
            "legacy_time_on_page_cutoff" => "2021-01-05T00:00:00Z",
            "imports" => true
          }
        })

      assert_matches %{
                       "results" => [
                         %{"dimensions" => [], "metrics" => [180]}
                       ],
                       "meta" =>
                         ^strict_map(%{
                           "imports_included" => true,
                           "metric_warnings" => %{
                             "time_on_page" => %{
                               "code" => "legacy_time_on_page_used",
                               "message" =>
                                 "Contains less accurate legacy time-on-page data up to 2021-01-05 00:00:00"
                             }
                           }
                         })
                     } = json_response(conn, 200)
    end

    test "aggregation with cutoff being mid-data (two queries joined)", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => "all",
          "filters" => [["is", "event:page", ["/blog"]]],
          "include" => %{
            "legacy_time_on_page_cutoff" => "2021-01-02T00:00:00Z",
            "imports" => true
          }
        })

      assert_matches %{
                       "results" => [
                         %{"dimensions" => [], "metrics" => [180]}
                       ],
                       "meta" =>
                         ^strict_map(%{
                           "imports_included" => true,
                           "metric_warnings" => %{
                             "time_on_page" => %{
                               "code" => "legacy_time_on_page_used",
                               "message" =>
                                 "Contains less accurate legacy time-on-page data up to 2021-01-02 00:00:00"
                             }
                           }
                         })
                     } = json_response(conn, 200)
    end

    test "aggregation with cutoff being mid-data (two queries joined), no imports", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => "all",
          "filters" => [["is", "event:page", ["/blog"]]],
          "include" => %{
            "legacy_time_on_page_cutoff" => "2021-01-02T00:00:00Z"
          }
        })

      assert_matches %{
                       "results" => [
                         %{"dimensions" => [], "metrics" => [180]}
                       ],
                       "meta" =>
                         ^strict_map(%{
                           "metric_warnings" => %{
                             "time_on_page" => %{
                               "code" => "legacy_time_on_page_used",
                               "message" =>
                                 "Contains less accurate legacy time-on-page data up to 2021-01-02 00:00:00"
                             }
                           }
                         })
                     } = json_response(conn, 200)
    end
  end

  describe "legacy time_on_page metric" do
    test "aggregated", %{conn: conn, site: site, site_import: site_import} do
      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/A", user_id: 111, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 111, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, pathname: "/A", user_id: 999, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 999, timestamp: ~N[2021-01-02 00:01:30]),
        # These are ignored for time_on_page metric
        build(:imported_pages, page: "/A", total_time_on_page: 40, date: ~D[2021-01-01]),
        build(:imported_pages, page: "/B", total_time_on_page: 499, date: ~D[2021-01-01])
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "time_on_page"],
          "date_range" => "all",
          "filters" => [["is", "event:page", ["/A"]]],
          "include" => %{
            "imports" => true,
            "legacy_time_on_page_cutoff" => "2100-01-01T00:00:00Z"
          }
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => [], "metrics" => [3, 75]}
             ]
    end

    test "breakdown", %{conn: conn, site: site, site_import: site_import} do
      populate_stats(site, site_import.id, [
        build(:pageview, pathname: "/A", user_id: 111, timestamp: ~N[2021-01-01 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 111, timestamp: ~N[2021-01-01 00:01:00]),
        build(:pageview, pathname: "/A", user_id: 999, timestamp: ~N[2021-01-02 00:00:00]),
        build(:pageview, pathname: "/B", user_id: 999, timestamp: ~N[2021-01-02 00:01:30]),
        build(:pageview, pathname: "/C", user_id: 999, timestamp: ~N[2021-01-02 00:02:00]),
        build(:imported_pages, page: "/A", total_time_on_page: 40, date: ~D[2021-01-01]),
        build(:imported_pages, page: "/B", total_time_on_page: 499, date: ~D[2021-01-01])
      ])

      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "time_on_page"],
          "date_range" => "all",
          "dimensions" => ["event:page"],
          "include" => %{
            "imports" => true,
            "legacy_time_on_page_cutoff" => "2100-01-01T00:00:00Z"
          }
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["/A"], "metrics" => [3, 63]},
               %{"dimensions" => ["/B"], "metrics" => [3, 264]},
               %{"dimensions" => ["/C"], "metrics" => [1, nil]}
             ]
    end
  end

  describe "timeseries" do
    setup %{site: site} = context do
      populate_stats(site, [
        build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-01 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/",
          timestamp: ~N[2021-01-01 00:05:00],
          engagement_time: 100_000
        ),
        build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-02 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/",
          timestamp: ~N[2021-01-02 00:05:00],
          engagement_time: 200_000
        ),
        build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-03 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/",
          timestamp: ~N[2021-01-03 00:05:00],
          engagement_time: 250_000
        ),
        build(:pageview, user_id: 12, pathname: "/", timestamp: ~N[2021-01-04 00:00:00]),
        build(:engagement,
          user_id: 12,
          pathname: "/",
          timestamp: ~N[2021-01-04 00:05:00],
          engagement_time: 200_000
        ),
        build(:pageview, user_id: 13, pathname: "/", timestamp: ~N[2021-01-04 00:00:00]),
        build(:engagement,
          user_id: 13,
          pathname: "/",
          timestamp: ~N[2021-01-04 00:05:00],
          engagement_time: 100_000
        )
      ])

      context
    end

    test "reports average new time-on-page per day", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => ["2021-01-01", "2021-01-04"],
          "filters" => [["is", "event:page", ["/"]]],
          "dimensions" => ["time:day"]
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [100]},
               %{"dimensions" => ["2021-01-02"], "metrics" => [200]},
               %{"dimensions" => ["2021-01-03"], "metrics" => [250]},
               %{"dimensions" => ["2021-01-04"], "metrics" => [150]}
             ]
    end

    test "reports legacy time-on-page as nulls per day", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => ["2021-01-01", "2021-01-04"],
          "filters" => [["is", "event:page", ["/"]]],
          "dimensions" => ["time:day"],
          "include" => %{"legacy_time_on_page_cutoff" => "2100-01-01T00:00:00Z"}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [nil]},
               %{"dimensions" => ["2021-01-02"], "metrics" => [nil]},
               %{"dimensions" => ["2021-01-03"], "metrics" => [nil]},
               %{"dimensions" => ["2021-01-04"], "metrics" => [nil]}
             ]
    end

    test "respects `legacy_time_on_page_cutoff`", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => ["2021-01-01", "2021-01-04"],
          "filters" => [["is", "event:page", ["/"]]],
          "dimensions" => ["time:day"],
          "include" => %{"legacy_time_on_page_cutoff" => "2021-01-02T23:59:59Z"}
        })

      assert json_response(conn, 200)["results"] == [
               %{"dimensions" => ["2021-01-01"], "metrics" => [nil]},
               %{"dimensions" => ["2021-01-02"], "metrics" => [nil]},
               %{"dimensions" => ["2021-01-03"], "metrics" => [250]},
               %{"dimensions" => ["2021-01-04"], "metrics" => [150]}
             ]
    end

    test "can use comparisons together with `legacy_time_on_page_cutoff`", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/api/v2/query-internal-test", %{
          "site_id" => site.domain,
          "metrics" => ["time_on_page"],
          "date_range" => ["2021-01-03", "2021-01-04"],
          "filters" => [["is", "event:page", ["/"]]],
          "dimensions" => ["time:day"],
          "include" => %{
            "legacy_time_on_page_cutoff" => "2021-01-01T23:59:59Z",
            "comparisons" => %{"mode" => "previous_period"}
          }
        })

      assert json_response(conn, 200)["results"] == [
               %{
                 "dimensions" => ["2021-01-03"],
                 "metrics" => [250],
                 "comparison" => %{
                   "dimensions" => ["2021-01-01"],
                   "metrics" => [nil],
                   "change" => [nil]
                 }
               },
               %{
                 "dimensions" => ["2021-01-04"],
                 "metrics" => [150],
                 "comparison" => %{
                   "dimensions" => ["2021-01-02"],
                   "metrics" => [200],
                   "change" => [-25]
                 }
               }
             ]
    end
  end
end
