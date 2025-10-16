defmodule PlausibleWeb.Api.ExternalStatsController.QueryTimezoneTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  describe "query parser timezone conversion for date ranges" do
    test "uses site timezone to determine 'today' (negative offset)", %{
      conn: conn,
      site: site
    } do
      site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/New_York"))

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2024-01-01 12:00:00]),
        build(:pageview, timestamp: ~N[2024-01-02 12:00:00]),
        build(:pageview, timestamp: ~N[2024-01-02 14:00:00])
      ])

      # 9pm on Jan 1st, 2024 in EST (UTC-5)
      Plausible.Stats.Query.Test.fix_now(~U[2024-01-02 02:00:00Z])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => "day"
        })

      response = json_response(conn, 200)

      assert [%{"metrics" => [pageview_count], "dimensions" => []}] = response["results"]
      assert pageview_count == 1
    end

    test "uses site timezone to determine 'today' (positive offset)", %{
      conn: conn,
      site: site
    } do
      site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "Asia/Tokyo"))

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2024-01-01 10:00:00]),
        build(:pageview, timestamp: ~N[2024-01-01 12:00:00]),
        build(:pageview, timestamp: ~N[2024-01-02 12:00:00])
      ])

      # 01:00 on Jan 2nd, 2024 in JST (UTC+9)
      Plausible.Stats.Query.Test.fix_now(~U[2024-01-01 16:00:00Z])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => "day"
        })

      response = json_response(conn, 200)

      assert [%{"metrics" => [pageview_count], "dimensions" => []}] = response["results"]
      assert pageview_count == 1
    end

    test "handles timezone gap when date starts at non-existent midnight (spring forward)", %{
      conn: conn,
      site: site
    } do
      # On 2022-09-11 in America/Santiago, clocks spring forward from 00:00 to 01:00
      # So midnight doesn't exist - it's a "gap"
      site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/Santiago"))

      populate_stats(site, [
        # 2022-09-11 03:59:00 UTC = 2022-09-10 23:59:00 CLT (before gap)
        build(:pageview, timestamp: ~N[2022-09-11 03:59:00]),
        # 2022-09-11 04:00:00 UTC = 2022-09-11 01:00:00 CLT (after gap - midnight doesn't exist)
        build(:pageview, timestamp: ~N[2022-09-11 04:00:00]),
        # 2022-09-11 05:00:00 UTC = 2022-09-11 02:00:00 CLT (well after gap)
        build(:pageview, timestamp: ~N[2022-09-11 05:00:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => ["2022-09-11", "2022-09-11"]
        })

      response = json_response(conn, 200)

      # Should include pageviews from 01:00:00 CLT onwards (after the gap)
      assert [%{"metrics" => [pageview_count], "dimensions" => []}] = response["results"]
      assert pageview_count == 2
    end

    test "handles ambiguous datetime at start of range (fall back)", %{
      conn: conn,
      site: site
    } do
      # On 2023-11-05 in America/Havana, clocks fall back at 01:00 CDT to 00:00 EST
      # So 00:00:00 happens twice - it's "ambiguous"
      site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/Havana"))

      populate_stats(site, [
        # 2023-11-05 04:30:00 UTC = 2023-11-05 00:30:00 CDT (in first occurrence hour)
        build(:pageview, timestamp: ~N[2023-11-05 04:30:00]),
        # 2023-11-05 05:30:00 UTC = 2023-11-05 00:30:00 EST (in second occurrence hour)
        build(:pageview, timestamp: ~N[2023-11-05 05:30:00]),
        # 2023-11-05 06:30:00 UTC = 2023-11-05 01:30:00 EST
        build(:pageview, timestamp: ~N[2023-11-05 06:30:00])
      ])

      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => ["2023-11-05", "2023-11-05"]
        })

      response = json_response(conn, 200)

      # Range is 05:00:00 UTC to 04:59:59 UTC next day
      # Should include pageviews at 05:30 and 06:30 (2 pageviews)
      assert [%{"metrics" => [pageview_count], "dimensions" => []}] = response["results"]
      assert pageview_count == 2
    end

    test "handles ambiguous datetime at end of range (fall back)", %{
      conn: conn,
      site: site
    } do
      # On 2024-03-23 in America/Asuncion, clocks fall back creating ambiguous times
      site = Plausible.Repo.update!(Ecto.Changeset.change(site, timezone: "America/Asuncion"))

      populate_stats(site, [
        # 2024-03-23 12:00:00 UTC = 2024-03-23 09:00:00 PYT (during the day)
        build(:pageview, timestamp: ~N[2024-03-23 12:00:00]),
        # 2024-03-24 02:58:00 UTC = 2024-03-23 23:58:00 PYT (before end of day)
        build(:pageview, timestamp: ~N[2024-03-24 02:58:00]),
        # 2024-03-24 03:00:00 UTC = 2024-03-24 00:00:00 PYT (next day)
        build(:pageview, timestamp: ~N[2024-03-24 03:00:00])
      ])

      # Query for just the 23rd
      conn =
        post(conn, "/api/v2/query", %{
          "site_id" => site.domain,
          "metrics" => ["pageviews"],
          "date_range" => ["2024-03-23", "2024-03-23"]
        })

      response = json_response(conn, 200)

      # Should include first 2 pageviews but not the third (which is on the 24th)
      assert [%{"metrics" => [pageview_count], "dimensions" => []}] = response["results"]
      assert pageview_count == 2
    end
  end
end
