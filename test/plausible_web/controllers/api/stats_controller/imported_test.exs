defmodule PlausibleWeb.Api.StatsController.ImportedTest do
  use PlausibleWeb.ConnCase

  @user_id Enum.random(1000..9999)

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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&with_imported=true"
          )

        assert %{"plot" => plot} = json_response(conn, 200)

        assert Enum.count(plot) == 31
        assert List.first(plot) == 2
        assert List.last(plot) == 2
        assert Enum.sum(plot) == 4
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/main-graph?period=month&date=2021-01-01&with_imported=true&interval=week"
          )

        assert %{"plot" => plot} = json_response(conn, 200)

        assert Enum.count(plot) == 5
        assert List.first(plot) == 2
        assert List.last(plot) == 2
        assert Enum.sum(plot) == 4
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

        results =
          conn
          |> get(
            "/api/stats/#{site.domain}/sources?period=month&date=2021-01-01&with_imported=true"
          )
          |> json_response(200)
          |> Map.get("results")
          |> Enum.sort()

        assert results == [
                 %{"name" => "A Nice Newsletter", "visitors" => 1},
                 %{"name" => "Direct / None", "visitors" => 1},
                 %{"name" => "DuckDuckGo", "visitors" => 2},
                 %{"name" => "Google", "visitors" => 4},
                 %{"name" => "Twitter", "visitors" => 1}
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

        results =
          conn
          |> get(
            "/api/stats/#{site.domain}/channels?period=month&date=2021-01-01&with_imported=true"
          )
          |> json_response(200)
          |> Map.get("results")
          |> Enum.sort()

        assert results == [
                 %{"name" => "(not set)", "visitors" => 1},
                 %{"name" => "Direct", "visitors" => 2},
                 %{"name" => "Organic Search", "visitors" => 3},
                 %{"name" => "Paid Search", "visitors" => 2}
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/utm_mediums?period=day&date=2021-01-01&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
                 %{
                   "bounce_rate" => 100.0,
                   "name" => "social",
                   "visit_duration" => 20,
                   "visitors" => 3
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/utm_campaigns?period=day&date=2021-01-01&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/utm_terms?period=day&date=2021-01-01&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
                 %{
                   "name" => "Sweden",
                   "visitors" => 3,
                   "bounce_rate" => 67.0,
                   "visit_duration" => 33.0
                 },
                 %{
                   "name" => "oat milk",
                   "visitors" => 2,
                   "bounce_rate" => 100.0,
                   "visit_duration" => 50.0
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/utm_contents?period=day&date=2021-01-01&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
                 %{
                   "name" => "ad",
                   "visitors" => 2,
                   "bounce_rate" => 100.0,
                   "visit_duration" => 50.0
                 },
                 %{
                   "name" => "blog",
                   "visitors" => 2,
                   "bounce_rate" => 50.0,
                   "visit_duration" => 50.0
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&detailed=true&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
                 %{
                   "bounce_rate" => 0,
                   "time_on_page" => 60,
                   "visitors" => 3,
                   "pageviews" => 4,
                   "scroll_depth" => nil,
                   "name" => "/some-other-page"
                 },
                 %{
                   "bounce_rate" => 25.0,
                   "time_on_page" => 700,
                   "visitors" => 2,
                   "pageviews" => 2,
                   "scroll_depth" => nil,
                   "name" => "/"
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/cities?period=day&date=2021-01-01&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
                 %{"code" => 588_335, "name" => "Tartu", "visitors" => 1, "country_flag" => "🇪🇪"},
                 %{
                   "code" => 2_650_225,
                   "name" => "Edinburgh",
                   "visitors" => 1,
                   "country_flag" => "🇬🇧"
                 }
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/countries?period=day&date=2021-01-01&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/screen-sizes?period=day&date=2021-01-01&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
                 %{"name" => "Desktop", "visitors" => 2, "percentage" => 40},
                 %{"name" => "Laptop", "visitors" => 2, "percentage" => 40},
                 %{"name" => "Mobile", "visitors" => 1, "percentage" => 20}
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/browsers?period=day&date=2021-01-01&with_imported=true"
          )

        assert stats = json_response(conn, 200)["results"]
        assert length(stats) == 3
        assert %{"name" => "Firefox", "visitors" => 2, "percentage" => 50.0} in stats
        assert %{"name" => "Mobile App", "visitors" => 1, "percentage" => 25.0} in stats
        assert %{"name" => "Chrome", "visitors" => 1, "percentage" => 25.0} in stats
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/operating-systems?period=day&date=2021-01-01&with_imported=true"
          )

        assert json_response(conn, 200)["results"] == [
                 %{"name" => "Mac", "visitors" => 3, "percentage" => 60},
                 %{"name" => "GNU/Linux", "visitors" => 2, "percentage" => 40}
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

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/top-stats?period=month&date=2021-01-01&with_imported=true"
          )

        assert %{"top_stats" => top_stats} = json_response(conn, 200)

        visit_duration = Enum.find(top_stats, fn stat -> stat["name"] == "Visit duration" end)

        assert visit_duration["value"] == 3_479_032
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
                   %{"name" => "Views per visit", "value" => 1.0},
                   %{"name" => "Bounce rate", "value" => 0},
                   %{"name" => "Visit duration", "value" => 60}
                 ]
               } = json_response(conn, 200)
      end
    end
  end
end
