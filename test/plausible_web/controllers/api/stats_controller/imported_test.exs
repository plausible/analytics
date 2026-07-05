defmodule PlausibleWeb.Api.StatsController.ImportedTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

  defp do_query(conn, site, params) do
    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  defp import_data(ga_data, site_id, import_id, table_name) do
    ga_data
    |> Plausible.Imported.GoogleAnalytics4.from_report(site_id, import_id, table_name)
    |> then(&Plausible.Imported.Buffer.insert_all(table_name, &1))
  end

  for import_type <- [:new_and_legacy, :new] do
    describe "Parse and import third party data fetched from Google Analytics as #{import_type} import" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user, site: site} do
        import_params =
          %{
            source: :google_analytics_4,
            start_date: ~D[2005-01-01],
            end_date: Date.utc_today(),
            legacy: unquote(import_type) == :new_and_legacy
          }

        site_import =
          site
          |> Plausible.Imported.SiteImport.create_changeset(
            user,
            import_params
          )
          |> Plausible.Repo.insert!()
          |> Plausible.Imported.SiteImport.complete_changeset()
          |> Plausible.Repo.update!()

        {:ok, %{import_id: site_import.id}}
      end

      test "Visitors data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, [
          build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
        ])

        import_data(
          [
            %{
              dimensions: %{"date" => "20210101"},
              metrics: %{
                "totalUsers" => "1",
                "screenPageViews" => "1",
                "bounces" => "0",
                "sessions" => "1",
                "userEngagementDuration" => "60"
              }
            },
            %{
              dimensions: %{"date" => "20210131"},
              metrics: %{
                "totalUsers" => "1",
                "screenPageViews" => "1",
                "bounces" => "0",
                "sessions" => "1",
                "userEngagementDuration" => "60"
              }
            }
          ],
          site.id,
          import_id,
          "imported_visitors"
        )

        params = %{
          "date_range" => "month",
          "metrics" => ["visitors"],
          "relative_date" => "2021-01-01",
          "dimensions" => ["time:day"],
          "include" => %{"imports" => true, "time_labels" => true}
        }

        response = do_query(conn, site, params)

        assert length(response["meta"]["time_labels"]) == 31

        assert response["results"] == [
                 %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
                 %{"dimensions" => ["2021-01-31"], "metrics" => [2]}
               ]
      end

      test "returns data grouped by week", %{conn: conn, site: site, import_id: import_id} do
        populate_stats(site, [
          build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
        ])

        import_data(
          [
            %{
              dimensions: %{"date" => "20210101"},
              metrics: %{
                "totalUsers" => "1",
                "screenPageViews" => "1",
                "bounces" => "0",
                "sessions" => "1",
                "userEngagementDuration" => "60"
              }
            },
            %{
              dimensions: %{"date" => "20210131"},
              metrics: %{
                "totalUsers" => "1",
                "screenPageViews" => "1",
                "bounces" => "0",
                "sessions" => "1",
                "userEngagementDuration" => "60"
              }
            }
          ],
          site.id,
          import_id,
          "imported_visitors"
        )

        params = %{
          "date_range" => "month",
          "metrics" => ["visitors"],
          "relative_date" => "2021-01-01",
          "dimensions" => ["time:week"],
          "include" => %{"imports" => true, "time_labels" => true}
        }

        response = do_query(conn, site, params)

        assert length(response["meta"]["time_labels"]) == 5

        assert response["results"] == [
                 %{"dimensions" => ["2021-01-01"], "metrics" => [2]},
                 %{"dimensions" => ["2021-01-25"], "metrics" => [2]}
               ]
      end

      test "Sources are imported", %{conn: conn, site: site, import_id: import_id} do
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

        populate_stats(site, import_id, [
          build(:imported_visitors, date: ~D[2021-01-01]),
          build(:imported_visitors, date: ~D[2021-01-01]),
          build(:imported_visitors, date: ~D[2021-01-01]),
          build(:imported_visitors, date: ~D[2021-01-01]),
          build(:imported_visitors, date: ~D[2021-01-31]),
          build(:imported_visitors, date: ~D[2021-01-31])
        ])

        import_data(
          [
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "organic",
                "sessionSource" => "duckduckgo.com",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210131",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "organic",
                "sessionSource" => "google.com",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "paid",
                "sessionSource" => "google.com",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "social",
                "sessionSource" => "Twitter",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "newsletter",
                "date" => "20210131",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "email",
                "sessionSource" => "A Nice Newsletter",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "(none)",
                "sessionSource" => "(direct)",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_sources"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-31"],
            "dimensions" => ["visit:source"],
            "metrics" => ["visitors", "percentage"],
            "order_by" => [["visit:source", "asc"]],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{"dimensions" => ["A Nice Newsletter"], "metrics" => [1, 11.11]},
                 %{"dimensions" => ["Direct / None"], "metrics" => [1, 11.11]},
                 %{"dimensions" => ["DuckDuckGo"], "metrics" => [2, 22.22]},
                 %{"dimensions" => ["Google"], "metrics" => [4, 44.44]},
                 %{"dimensions" => ["X (Twitter)"], "metrics" => [1, 11.11]}
               ]
      end

      test "Channels are imported", %{conn: conn, site: site, import_id: import_id} do
        populate_stats(site, [
          # Organic Search
          build(:pageview,
            referrer_source: "Bing",
            timestamp: ~N[2021-01-01 00:00:00]
          ),
          # Paid Search
          build(:pageview,
            referrer_source: "Google",
            utm_medium: "paid",
            timestamp: ~N[2021-01-01 00:00:00]
          ),
          # Direct
          build(:pageview,
            timestamp: ~N[2021-01-01 00:00:00]
          )
        ])

        import_data(
          [
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "organic",
                "sessionSource" => "duckduckgo.com",
                "sessionDefaultChannelGroup" => "Organic Search"
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210131",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "organic",
                "sessionSource" => "google.com",
                "sessionDefaultChannelGroup" => "Organic Search"
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "paid",
                "sessionSource" => "google.com",
                "sessionDefaultChannelGroup" => "Paid Search"
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "(none)",
                "sessionSource" => "(direct)",
                "sessionDefaultChannelGroup" => "Direct"
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "(none)",
                "sessionSource" => "(direct)",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_sources"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-31"],
            "dimensions" => ["visit:channel"],
            "metrics" => ["visitors", "percentage"],
            "order_by" => [["visit:channel", "asc"]],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{"dimensions" => ["(not set)"], "metrics" => [1, 33.33]},
                 %{"dimensions" => ["Direct"], "metrics" => [2, 66.67]},
                 %{"dimensions" => ["Organic Search"], "metrics" => [3, 100.0]},
                 %{"dimensions" => ["Paid Search"], "metrics" => [2, 66.67]}
               ]
      end

      test "UTM mediums data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
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
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "social",
                "sessionSource" => "Twitter",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "(none)",
                "sessionSource" => "(direct)",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_sources"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:utm_medium"],
            "filters" => [["is_not", "visit:utm_medium", [""]]],
            "metrics" => ["visitors", "bounce_rate", "visit_duration", "percentage"],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{
                   "dimensions" => ["social"],
                   "metrics" => [3, 100, 20, 100.0]
                 }
               ]
      end

      test "UTM campaigns data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, [
          build(:pageview, utm_campaign: "profile", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, utm_campaign: "august", timestamp: ~N[2021-01-01 00:00:00])
        ])

        import_data(
          [
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "profile",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "social",
                "sessionSource" => "Twitter",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "august",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "email",
                "sessionSource" => "Gmail",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "(not set)",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "email",
                "sessionSource" => "Gmail",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_sources"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:utm_campaign"],
            "filters" => [["is_not", "visit:utm_campaign", [""]]],
            "order_by" => [["visit:utm_campaign", "asc"]],
            "metrics" => ["visitors", "bounce_rate", "visit_duration", "percentage"],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{
                   "dimensions" => ["august"],
                   "metrics" => [2, 50, 50, 50.0]
                 },
                 %{
                   "dimensions" => ["profile"],
                   "metrics" => [2, 100, 50, 50.0]
                 }
               ]
      end

      test "UTM terms data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, [
          build(:pageview, utm_term: "oat milk", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, utm_term: "Sweden", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, utm_term: "Sweden", timestamp: ~N[2021-01-01 00:00:00])
        ])

        import_data(
          [
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "oat milk",
                "sessionMedium" => "paid",
                "sessionSource" => "Google",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "Sweden",
                "sessionMedium" => "paid",
                "sessionSource" => "Google",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "(not set)",
                "sessionMedium" => "paid",
                "sessionSource" => "Google",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_sources"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:utm_term"],
            "filters" => [["is_not", "visit:utm_term", [""]]],
            "metrics" => ["visitors", "bounce_rate", "visit_duration", "percentage"],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{
                   "dimensions" => ["Sweden"],
                   "metrics" => [3, 67, 33, 60.0]
                 },
                 %{
                   "dimensions" => ["oat milk"],
                   "metrics" => [2, 100, 50, 40.0]
                 }
               ]
      end

      test "UTM contents data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, [
          build(:pageview, utm_content: "ad", timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, utm_content: "blog", timestamp: ~N[2021-01-01 00:00:00])
        ])

        import_data(
          [
            %{
              dimensions: %{
                "sessionManualAdContent" => "ad",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "paid",
                "sessionSource" => "Google",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "1",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "blog",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "paid",
                "sessionSource" => "Google",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "sessionManualAdContent" => "(not set)",
                "sessionCampaignName" => "",
                "date" => "20210101",
                "sessionGoogleAdsKeyword" => "",
                "sessionMedium" => "paid",
                "sessionSource" => "Google",
                "sessionDefaultChannelGroup" => ""
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "100",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_sources"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:utm_content"],
            "filters" => [["is_not", "visit:utm_content", [""]]],
            "order_by" => [["bounce_rate", "desc"]],
            "metrics" => ["visitors", "bounce_rate", "visit_duration", "percentage"],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{
                   "dimensions" => ["ad"],
                   "metrics" => [2, 100, 50, 50.0]
                 },
                 %{
                   "dimensions" => ["blog"],
                   "metrics" => [2, 50, 50, 50.0]
                 }
               ]
      end

      test "Page event data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
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

        populate_stats(site, import_id, [
          build(:imported_visitors, date: ~D[2021-01-01]),
          build(:imported_visitors, date: ~D[2021-01-01]),
          build(:imported_visitors, date: ~D[2021-01-01]),
          build(:imported_visitors, date: ~D[2021-01-01])
        ])

        import_data(
          [
            %{
              dimensions: %{
                "date" => "20210101",
                "hostName" => "host-a.com",
                "pagePath" => "/"
              },
              metrics: %{
                "screenPageViews" => "1",
                "userEngagementDuration" => "700",
                "totalUsers" => "1",
                "activeUsers" => "1",
                "sessions" => "1"
              }
            },
            %{
              dimensions: %{
                "date" => "20210101",
                "hostName" => "host-b.com",
                "pagePath" => "/some-other-page"
              },
              metrics: %{
                "screenPageViews" => "2",
                "userEngagementDuration" => "60",
                "totalUsers" => "1",
                "activeUsers" => "1",
                "sessions" => "1"
              }
            },
            %{
              dimensions: %{
                "date" => "20210101",
                "hostName" => "host-b.com",
                "pagePath" => "/some-other-page?wat=wot"
              },
              metrics: %{
                "screenPageViews" => "1",
                "userEngagementDuration" => "60",
                "totalUsers" => "1",
                "activeUsers" => "1",
                "sessions" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_pages"
        )

        import_data(
          [
            %{
              dimensions: %{"date" => "20210101", "landingPage" => "/"},
              metrics: %{
                "bounces" => "1",
                "sessions" => "3",
                "userEngagementDuration" => "10",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_entry_pages"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["event:page"],
            "metrics" => [
              "visitors",
              "pageviews",
              "bounce_rate",
              "time_on_page",
              "scroll_depth",
              "percentage"
            ],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{
                   "dimensions" => ["/some-other-page"],
                   "metrics" => [3, 4, 0, 60, nil, 60.0]
                 },
                 %{
                   "dimensions" => ["/"],
                   "metrics" => [2, 2, 25, 700, nil, 40.0]
                 }
               ]
      end

      test "imports city data from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
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
                "countryId" => "EE",
                "city" => "Tartu",
                "date" => "20210101",
                "region" => "Tartumaa"
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "countryId" => "GB",
                "city" => "Edinburgh",
                "date" => "20210101",
                "region" => "Midlothian"
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_locations"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:city_name", "visit:city", "visit:country"],
            "metrics" => ["visitors", "percentage"],
            "filters" => [["is_not", "visit:city", [0]]],
            "order_by" => [["visit:city_name", "desc"]],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{"dimensions" => ["Tartu", 588_335, "EE"], "metrics" => [1, 50.0]},
                 %{"dimensions" => ["Edinburgh", 2_650_225, "GB"], "metrics" => [1, 50.0]}
               ]
      end

      test "imports country data from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, import_id, [
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
                "countryId" => "EE",
                "city" => "Tartu",
                "date" => "20210101",
                "region" => "Tartumaa"
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "countryId" => "GB",
                "city" => "Edinburgh",
                "date" => "20210101",
                "region" => "Midlothian"
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_locations"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:country_name", "visit:country"],
            "metrics" => ["visitors", "percentage"],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{"dimensions" => ["Estonia", "EE"], "metrics" => [3, 60.0]},
                 %{"dimensions" => ["United Kingdom", "GB"], "metrics" => [2, 40.0]}
               ]
      end

      test "Devices data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, import_id, [
          build(:pageview, screen_size: "Desktop", timestamp: ~N[2021-01-01 00:15:00]),
          build(:pageview, screen_size: "Desktop", timestamp: ~N[2021-01-01 00:15:00]),
          build(:pageview, screen_size: "Laptop", timestamp: ~N[2021-01-01 00:15:00]),
          build(:imported_visitors, date: ~D[2021-01-01], visitors: 2)
        ])

        import_data(
          [
            %{
              dimensions: %{"date" => "20210101", "deviceCategory" => "mobile"},
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{"date" => "20210101", "deviceCategory" => "Laptop"},
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_devices"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:device"],
            "order_by" => [["visitors", "desc"], ["visit:device", "asc"]],
            "metrics" => ["visitors", "percentage"],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{"dimensions" => ["Desktop"], "metrics" => [2, 40.0]},
                 %{"dimensions" => ["Laptop"], "metrics" => [2, 40.0]},
                 %{"dimensions" => ["Mobile"], "metrics" => [1, 20.0]}
               ]
      end

      test "Browsers data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, import_id, [
          build(:pageview, browser: "Chrome", timestamp: ~N[2021-01-01 00:15:00]),
          build(:pageview, browser: "Firefox", timestamp: ~N[2021-01-01 00:15:00]),
          build(:imported_visitors, visitors: 2, date: ~D[2021-01-01])
        ])

        import_data(
          [
            %{
              dimensions: %{
                "browser" => "User-Agent: Mozilla",
                "date" => "20210101"
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{"browser" => "Android Browser", "date" => "20210101"},
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_browsers"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:browser"],
            "order_by" => [["visitors", "desc"], ["visit:browser", "asc"]],
            "metrics" => ["visitors", "percentage"],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{"dimensions" => ["Firefox"], "metrics" => [2, 50.0]},
                 %{"dimensions" => ["Chrome"], "metrics" => [1, 25.0]},
                 %{"dimensions" => ["Mobile App"], "metrics" => [1, 25.0]}
               ]
      end

      test "OS data imported from Google Analytics", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, import_id, [
          build(:pageview, operating_system: "Mac", timestamp: ~N[2021-01-01 00:15:00]),
          build(:pageview, operating_system: "Mac", timestamp: ~N[2021-01-01 00:15:00]),
          build(:pageview,
            operating_system: "GNU/Linux",
            timestamp: ~N[2021-01-01 00:15:00]
          ),
          build(:imported_visitors, date: ~D[2021-01-01], visitors: 2)
        ])

        import_data(
          [
            %{
              dimensions: %{
                "date" => "20210101",
                "operatingSystem" => "Macintosh",
                "operatingSystemVersion" => "10.15.1"
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            },
            %{
              dimensions: %{
                "date" => "20210101",
                "operatingSystem" => "Linux",
                "operatingSystemVersion" => "12.12"
              },
              metrics: %{
                "bounces" => "0",
                "userEngagementDuration" => "10",
                "sessions" => "1",
                "totalUsers" => "1",
                "screenPageViews" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_operating_systems"
        )

        response =
          do_query(conn, site, %{
            "date_range" => ["2021-01-01", "2021-01-01"],
            "dimensions" => ["visit:os"],
            "metrics" => ["visitors", "percentage"],
            "include" => %{"imports" => true}
          })

        assert response["results"] == [
                 %{"dimensions" => ["Mac"], "metrics" => [3, 60.0]},
                 %{"dimensions" => ["GNU/Linux"], "metrics" => [2, 40.0]}
               ]
      end

      test "Can import visit duration with scientific notation", %{
        conn: conn,
        site: site,
        import_id: import_id
      } do
        populate_stats(site, [
          build(:pageview, timestamp: ~N[2021-01-01 00:00:00]),
          build(:pageview, timestamp: ~N[2021-01-31 00:00:00])
        ])

        import_data(
          [
            %{
              dimensions: %{"date" => "20210101"},
              metrics: %{
                "bounces" => "0",
                "screenPageViews" => "1",
                "userEngagementDuration" => "1.391607E7",
                "sessions" => "1",
                "totalUsers" => "1"
              }
            },
            %{
              dimensions: %{"date" => "20210131"},
              metrics: %{
                "bounces" => "1",
                "screenPageViews" => "1",
                "userEngagementDuration" => "60",
                "sessions" => "1",
                "totalUsers" => "1"
              }
            }
          ],
          site.id,
          import_id,
          "imported_visitors"
        )

        params = %{
          "metrics" => ["visit_duration"],
          "date_range" => ["2021-01-01", "2021-01-31"],
          "include" => %{"imports" => true},
          "filters" => []
        }

        response = do_query(conn, site, params)

        assert response["results"] == [
                 %{"dimensions" => [], "metrics" => [3_479_032]}
               ]
      end

      test "skips empty dates from import", %{conn: conn, site: site, import_id: import_id} do
        import_data(
          [
            %{
              dimensions: %{"date" => "20210101"},
              metrics: %{
                "totalUsers" => "1",
                "screenPageViews" => "1",
                "bounces" => "0",
                "sessions" => "1",
                "userEngagementDuration" => "60"
              }
            },
            %{
              dimensions: %{"date" => "(other)"},
              metrics: %{
                "totalUsers" => "1",
                "screenPageViews" => "1",
                "bounces" => "0",
                "sessions" => "1",
                "userEngagementDuration" => "60"
              }
            }
          ],
          site.id,
          import_id,
          "imported_visitors"
        )

        params = %{
          "metrics" => [
            "visitors",
            "visits",
            "pageviews",
            "views_per_visit",
            "bounce_rate",
            "visit_duration"
          ],
          "date_range" => ["2021-01-01", "2021-01-31"],
          "include" => %{"imports" => true},
          "filters" => []
        }

        response = do_query(conn, site, params)

        assert response["results"] == [
                 %{"dimensions" => [], "metrics" => [1, 1, 1, 1, 0, 60]}
               ]
      end
    end
  end
end
