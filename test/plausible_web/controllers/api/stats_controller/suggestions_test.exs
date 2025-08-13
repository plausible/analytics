defmodule PlausibleWeb.Api.StatsController.SuggestionsTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/suggestions/:filter_name" do
    setup [:create_user, :log_in, :create_site]

    test "returns suggestions for pages without a query", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], pathname: "/"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], pathname: "/register"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/contact"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/irrelevant")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"label" => "/", "value" => "/"},
               %{"label" => "/contact", "value" => "/contact"},
               %{"label" => "/irrelevant", "value" => "/irrelevant"},
               %{"label" => "/register", "value" => "/register"}
             ]
    end

    test "returns suggestions for pages with a query", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], pathname: "/"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], pathname: "/register"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/contact"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/irrelevant")
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01&q=re")

      assert json_response(conn, 200) == [
               %{"label" => "/irrelevant", "value" => "/irrelevant"},
               %{"label" => "/register", "value" => "/register"}
             ]
    end

    test "returns suggestions for pages without any suggestions", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01&q=/123"
        )

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for goals", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/goal?period=month&date=2019-01-01&q=")

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for configured site goals but not all event names", %{
      conn: conn,
      site: site
    } do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:event, name: "Signup", timestamp: ~N[2019-01-01 00:00:00]),
        build(:event, name: "another", timestamp: ~N[2019-01-01 00:00:00])
      ])

      conn = get(conn, "/api/stats/#{site.domain}/suggestions/goal?period=day&date=2019-01-01&q=")

      assert json_response(conn, 200) == [%{"label" => "Signup", "value" => "Signup"}]
    end

    test "returns suggestions for sources", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], referrer_source: "Bing"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], referrer_source: "Bing"),
        build(:pageview,
          timestamp: ~N[2019-01-01 23:00:00],
          referrer_source: "10words"
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/source?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"label" => "Direct / None", "value" => "Direct / None"},
               %{"label" => "Bing", "value" => "Bing"},
               %{"label" => "10words", "value" => "10words"}
             ]
    end

    test "returns suggestions for channels", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], referrer_source: "Bing"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], referrer_source: "Bing"),
        build(:pageview,
          timestamp: ~N[2019-01-01 23:00:00],
          referrer_source: "Youtube"
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/channel?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"label" => "Organic Search", "value" => "Organic Search"},
               %{"label" => "Organic Video", "value" => "Organic Video"}
             ]
    end

    test "returns suggestions for countries", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2019-01-01 23:00:01],
          pathname: "/",
          country_code: "US"
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&q=Unit"
        )

      assert json_response(conn, 200) == [%{"value" => "US", "label" => "United States"}]
    end

    test "returns suggestions for regions", %{conn: conn, user: user} do
      {:ok, [site: site]} = create_site(%{user: user})

      populate_stats(site, [
        build(:pageview, country_code: "EE", subdivision1_code: "EE-37"),
        build(:pageview, country_code: "EE", subdivision1_code: "EE-39")
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/region?period=day&q=Har"
        )

      assert json_response(conn, 200) == [%{"value" => "EE-37", "label" => "Harjumaa"}]
    end

    test "returns suggestions for cities", %{conn: conn, user: user} do
      {:ok, [site: site]} = create_site(%{user: user})

      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-37",
          city_geoname_id: 588_409
        ),
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-39",
          city_geoname_id: 591_632
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/city?period=day&q=Kär"
        )

      assert json_response(conn, 200) == [%{"value" => 591_632, "label" => "Kärdla"}]
    end

    test "returns suggestions for countries without country in search", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&q=GBR,UKR,URY"
        )

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for screen sizes", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2019-01-01 23:00:00],
          pathname: "/",
          screen_size: "Desktop"
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/screen?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [%{"value" => "Desktop", "label" => "Desktop"}]
    end

    test "returns suggestions for browsers", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2019-01-01 23:00:00],
          pathname: "/",
          browser: "Chrome"
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/browser?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [%{"label" => "Chrome", "value" => "Chrome"}]
    end

    test "returns suggestions for browser versions", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "visit:browser", ["Chrome"]]])

      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2019-01-01 00:00:00],
          browser: "Chrome",
          browser_version: "78.0"
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/browser_version?period=month&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [%{"value" => "78.0", "label" => "78.0"}]
    end

    test "returns suggestions for OS", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2019-01-01 00:00:00], operating_system: "Mac")
      ])

      conn = get(conn, "/api/stats/#{site.domain}/suggestions/os?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [%{"value" => "Mac", "label" => "Mac"}]
    end

    test "returns suggestions for OS versions", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "visit:os", ["Mac"]]])

      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2019-01-01 00:00:00],
          operating_system: "Mac",
          operating_system_version: "10.15"
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/os_version?period=month&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [%{"label" => "10.15", "value" => "10.15"}]
    end

    test "returns suggestions for OS versions with search", %{conn: conn, site: site} do
      filters = Jason.encode!([[:is, "visit:os", ["Mac"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/os_version?period=month&date=2019-01-01&filters=#{filters}&q=11"
        )

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for hostnames", %{conn: conn1, user: user} do
      {:ok, [site: site]} = create_site(%{user: user})

      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          hostname: "host-alice.example.com"
        ),
        build(:pageview,
          pathname: "/some-other-page",
          hostname: "host-bob.example.com",
          user_id: 123
        ),
        build(:pageview, pathname: "/exit", hostname: "host-carol.example.com", user_id: 123)
      ])

      conn =
        get(
          conn1,
          "/api/stats/#{site.domain}/suggestions/hostname?period=day&q=alice"
        )

      assert json_response(conn, 200) == [
               %{"value" => "host-alice.example.com", "label" => "host-alice.example.com"}
             ]

      conn =
        get(
          conn1,
          "/api/stats/#{site.domain}/suggestions/hostname?period=day&q=host"
        )

      suggestions = json_response(conn, 200)

      assert length(suggestions) == 3

      assert %{"label" => "host-alice.example.com", "value" => "host-alice.example.com"} in suggestions

      assert %{"label" => "host-carol.example.com", "value" => "host-carol.example.com"} in suggestions

      assert %{"label" => "host-bob.example.com", "value" => "host-bob.example.com"} in suggestions
    end

    test "returns suggestions for hostnames limited by shields", %{conn: conn1, user: user} do
      {:ok, [site: site]} = create_site(%{user: user})
      Plausible.Shields.add_hostname_rule(site, %{"hostname" => "*.example.com"})
      Plausible.Shields.add_hostname_rule(site, %{"hostname" => "erin.rogue.com"})

      populate_stats(site, [
        build(:pageview,
          pathname: "/",
          hostname: "host-alice.example.com"
        ),
        build(:pageview,
          pathname: "/some-other-page",
          hostname: "host-bob.example.com",
          user_id: 123
        ),
        build(:pageview, pathname: "/exit", hostname: "host-carol.example.com", user_id: 123),
        build(:pageview,
          pathname: "/",
          hostname: "host-dave.rogue.com"
        ),
        build(:pageview,
          pathname: "/",
          hostname: "erin.rogue.com"
        )
      ])

      conn =
        get(
          conn1,
          "/api/stats/#{site.domain}/suggestions/hostname?period=day&q=host"
        )

      results = json_response(conn, 200)

      assert length(results) == 3

      assert %{"label" => "host-alice.example.com", "value" => "host-alice.example.com"} in results

      assert %{"label" => "host-carol.example.com", "value" => "host-carol.example.com"} in results

      assert %{"label" => "host-bob.example.com", "value" => "host-bob.example.com"} in results

      conn =
        get(
          conn1,
          "/api/stats/#{site.domain}/suggestions/hostname?period=day&q=dave"
        )

      assert json_response(conn, 200) == []

      conn =
        get(
          conn1,
          "/api/stats/#{site.domain}/suggestions/hostname?period=day&q=rogue"
        )

      assert json_response(conn, 200) == [
               %{"label" => "erin.rogue.com", "value" => "erin.rogue.com"}
             ]
    end

    test "returns suggestions for referrers", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2019-01-01 23:00:00],
          pathname: "/",
          referrer: "10words.com/page1"
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/referrer?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"value" => "10words.com/page1", "label" => "10words.com/page1"}
             ]
    end
  end

  describe "suggestions for props" do
    setup [:create_user, :log_in, :create_site]

    test "returns suggestions for prop key ordered by count", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["logged_in"],
          "meta.value": ["false"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["logged_in"],
          "meta.value": ["false"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["dark_mode"],
          "meta.value": ["true"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01")

      assert json_response(conn, 200) == [
               %{"label" => "author", "value" => "author"},
               %{"label" => "logged_in", "value" => "logged_in"},
               %{"label" => "dark_mode", "value" => "dark_mode"}
             ]
    end

    test "returns prop key suggestions found in time frame", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author", "logged_in"],
          "meta.value": ["Uku Taht", "false"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["dark_mode"],
          "meta.value": ["true"],
          timestamp: ~N[2022-01-02 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01&q=")

      assert json_response(conn, 200) == [
               %{"label" => "author", "value" => "author"},
               %{"label" => "logged_in", "value" => "logged_in"}
             ]
    end

    test "returns prop key suggestions by a search string", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author", "logged_in"],
          "meta.value": ["Uku Taht", "false"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["dark_mode"],
          "meta.value": ["true"],
          timestamp: ~N[2022-01-02 00:00:00]
        )
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01&q=aut"
        )

      assert json_response(conn, 200) == [
               %{"label" => "author", "value" => "author"}
             ]
    end

    test "returns only prop keys which exist under filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author", "bank"],
          "meta.value": ["Uku", "a"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author", "serial_number"],
          "meta.value": ["Marko", "b"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is, "event:props:author", ["Uku"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"label" => "author", "value" => "author"},
               %{"label" => "bank", "value" => "bank"}
             ]
    end

    test "returns suggestions for prop key based on site.allowed_event_props list", %{
      conn: conn,
      site: site
    } do
      {:ok, site} = Plausible.Props.allow(site, ["author"])

      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["garbage1"],
          "meta.value": ["somegarbage1"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["garbage2"],
          "meta.value": ["somegarbage2"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01")

      assert json_response(conn, 200) == [
               %{"label" => "author", "value" => "author"}
             ]
    end

    test "does not filter out prop key suggestions by default (when site.allowed_event_props is nil)",
         %{
           conn: conn,
           site: site
         } do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["garbage1"],
          "meta.value": ["somegarbage1"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["garbage2"],
          "meta.value": ["somegarbage2"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01")

      suggestions = json_response(conn, 200)
      assert %{"label" => "author", "value" => "author"} in suggestions
      assert %{"label" => "garbage1", "value" => "garbage1"} in suggestions
      assert %{"label" => "garbage2", "value" => "garbage2"} in suggestions
    end

    test "returns suggestions for prop value ordered by count, but (none) value is always first",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Marko Saric"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["(none)"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/custom-prop-values/author?period=day&date=2022-01-01&filters=#{filters}&q="
        )

      assert json_response(conn, 200) == [
               %{"label" => "(none)", "value" => "(none)"},
               %{"label" => "Uku Taht", "value" => "Uku Taht"},
               %{"label" => "Marko Saric", "value" => "Marko Saric"}
             ]
    end

    test "returns (none) value as the first suggestion even when a search string is provided",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Marko Saric"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Marko Saric"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["(none)"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/custom-prop-values/author?period=day&date=2022-01-01&filters=#{filters}&q=Mar"
        )

      assert json_response(conn, 200) == [
               %{"label" => "(none)", "value" => "(none)"},
               %{"label" => "Marko Saric", "value" => "Marko Saric"}
             ]
    end

    test "does not show (none) value suggestion when all events have that prop_key", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Marko Saric"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["(none)"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/custom-prop-values/author?period=day&date=2022-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"label" => "Uku Taht", "value" => "Uku Taht"},
               %{"label" => "Marko Saric", "value" => "Marko Saric"}
             ]
    end

    test "returns prop value suggestions with multiple custom property filters in query", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author", "browser_language"],
          "meta.value": ["Uku Taht", "en-US"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author", "browser_language"],
          "meta.value": ["Uku Taht", "en-US"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["author", "browser_language"],
          "meta.value": ["Marko Saric", "de-DE"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview, timestamp: ~N[2022-01-01 00:00:00])
      ])

      filters =
        Jason.encode!([
          [:is_not, "event:props:browser_language", ["(none)"]],
          [:is, "event:props:author", ["Uku Taht"]]
        ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/custom-prop-values/browser_language?period=day&date=2022-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"label" => "en-US", "value" => "en-US"}
             ]
    end

    test "when date is borked, bad request is returned", %{
      conn: conn,
      site: site
    } do
      today = (Date.utc_today() |> Date.to_iso8601()) <> " 00:00:00"
      naive_today = NaiveDateTime.from_iso8601!(today)

      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Alice Bob"],
          timestamp: naive_today
        ),
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Cecil"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!([[:is_not, "event:props:author", ["(none)"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/custom-prop-values/author?period=all&date=CLEVER_SECURITY_RESEARCH&filters=#{filters}"
        )

      assert json_response(conn, 400) == %{
               "error" =>
                 "Failed to parse 'date' argument. Only ISO 8601 dates are allowed, e.g. `2019-09-07`, `2020-01-01`"
             }
    end
  end

  describe "imported data" do
    setup [:create_user, :log_in, :create_site, :create_site_import]

    test "merges country suggestions from native and imported data", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:pageview, timestamp: ~N[2019-01-01 23:00:01], country_code: "US"),
        build(:pageview, timestamp: ~N[2019-01-01 23:30:01], country_code: "US"),
        build(:pageview, timestamp: ~N[2019-01-01 23:40:01], country_code: "US"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:01], country_code: "GB"),
        build(:imported_locations, date: ~D[2019-01-01], country: "GB", pageviews: 3)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&q=Unit&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{"value" => "GB", "label" => "United Kingdom"},
               %{"value" => "US", "label" => "United States"}
             ]
    end

    test "ignores imported data in country suggestions when a different property is filtered by",
         %{
           conn: conn,
           site: site,
           site_import: site_import
         } do
      populate_stats(site, site_import.id, [
        build(:pageview, country_code: "EE", referrer_source: "Bing"),
        build(:imported_locations, country: "GB")
      ])

      filters = Jason.encode!([[:is, "visit:source", ["Bing"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=day&filters=#{filters}&q=&with_imported=true"
        )

      assert json_response(conn, 200) == [%{"value" => "EE", "label" => "Estonia"}]
    end

    test "queries imported countries when filtering by country", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:imported_locations, date: ~D[2019-01-01], country: "EE")
      ])

      filters = Jason.encode!([[:is, "visit:country", ["EE"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&filters=#{filters}&q=&with_imported=true"
        )

      assert json_response(conn, 200) == [%{"value" => "EE", "label" => "Estonia"}]
    end

    test "ignores imported country data when not requested", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:imported_locations, date: ~D[2019-01-01], country: "GB", pageviews: 3)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&q="
        )

      assert json_response(conn, 200) == []
    end

    for {q, label} <- [{"", "without filter"}, {"H", "with filter"}] do
      test "merges region suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, country_code: "EE", subdivision1_code: "EE-37"),
          build(:pageview, country_code: "EE", subdivision1_code: "EE-39"),
          build(:pageview, country_code: "EE", subdivision1_code: "EE-39"),
          build(:imported_locations, country: "EE", region: "EE-37", pageviews: 2)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/region?period=day&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => "EE-37", "label" => "Harjumaa"},
                 %{"value" => "EE-39", "label" => "Hiiumaa"}
               ]
      end
    end

    test "handles invalid region codes in imported data gracefully (GA4)", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      # NOTE: Currently, the regions imported from GA4 do not conform to region code standard
      # we are using. Instead, literal region names are persisted. Those names often do not
      # match the names from our region databases either. Regardless of that, we still consider
      # them when filtering suggestions.

      populate_stats(site, site_import.id, [
        build(:imported_locations, country: "EE", region: "EE-37", pageviews: 2),
        build(:imported_locations, country: "EE", region: "Hiiumaa", pageviews: 1)
      ])

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/region?period=day&q=&with_imported=true"
        )

      assert json_response(conn1, 200) == [
               %{"value" => "EE-37", "label" => "Harjumaa"},
               %{"value" => "Hiiumaa", "label" => "Hiiumaa"}
             ]

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/region?period=day&q=H&with_imported=true"
        )

      assert json_response(conn2, 200) == [
               %{"value" => "EE-37", "label" => "Harjumaa"},
               %{"value" => "Hiiumaa", "label" => "Hiiumaa"}
             ]
    end

    test "ignores imported data in region suggestions when a different property is filtered by",
         %{
           conn: conn,
           site: site,
           site_import: site_import
         } do
      populate_stats(site, site_import.id, [
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-39",
          referrer_source: "Bing"
        ),
        build(:imported_locations, country: "EE", region: "EE-37")
      ])

      filters = Jason.encode!([[:is, "visit:source", ["Bing"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/region?period=day&filters=#{filters}&q=&with_imported=true"
        )

      assert json_response(conn, 200) == [%{"value" => "EE-39", "label" => "Hiiumaa"}]
    end

    test "queries imported regions when filtering by region", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:imported_locations, date: ~D[2019-01-01], region: "EE-39")
      ])

      filters = Jason.encode!([[:is, "visit:region", ["EE-39"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/region?period=month&date=2019-01-01&filters=#{filters}&q=&with_imported=true"
        )

      assert json_response(conn, 200) == [%{"value" => "EE-39", "label" => "Hiiumaa"}]
    end

    test "ignores imported region data when not requested", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:imported_locations, country: "EE", region: "EE-37", pageviews: 2)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/region?q="
        )

      assert json_response(conn, 200) == []
    end

    for {q, label} <- [{"", "without filter"}, {"l", "with filter"}] do
      test "merges city suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview,
            country_code: "EE",
            subdivision1_code: "EE-37",
            city_geoname_id: 588_409
          ),
          build(:pageview,
            country_code: "EE",
            subdivision1_code: "EE-39",
            city_geoname_id: 591_632
          ),
          build(:pageview,
            country_code: "EE",
            subdivision1_code: "EE-39",
            city_geoname_id: 591_632
          ),
          build(:imported_locations, country: "EE", region: "EE-37", city: 588_409, pageviews: 2)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/city?period=day&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => 588_409, "label" => "Tallinn"},
                 %{"value" => 591_632, "label" => "Kärdla"}
               ]
      end
    end

    test "ignores imported data in city suggestions when a different property is filtered by", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:pageview,
          country_code: "EE",
          subdivision1_code: "EE-39",
          city_geoname_id: 591_632,
          referrer_source: "Bing"
        ),
        build(:imported_locations, country: "EE", region: "EE-37", city: 588_409)
      ])

      filters = Jason.encode!([[:is, "visit:source", ["Bing"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/city?period=day&filters=#{filters}&q=&with_imported=true"
        )

      assert json_response(conn, 200) == [%{"value" => 591_632, "label" => "Kärdla"}]
    end

    test "queries imported cities when filtering by city", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:imported_locations, date: ~D[2019-01-01], city: 591_632)
      ])

      filters = Jason.encode!([[:is, "visit:city", ["591632"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/city?period=month&date=2019-01-01&filters=#{filters}&q=&with_imported=true"
        )

      assert json_response(conn, 200) == [%{"value" => 591_632, "label" => "Kärdla"}]
    end

    test "ignores imported city data when not requested", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:imported_locations, country: "EE", region: "EE-37", city: 588_409, pageviews: 2)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/city?q="
        )

      assert json_response(conn, 200) == []
    end

    test "ignores imported data when asking for prop key and value suggestions", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:pageview,
          "meta.key": ["url"],
          "meta.value": ["http://example1.com"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:imported_custom_events,
          date: ~D[2022-01-01],
          name: "Outbound Link: Click",
          link_url: "http://example2.com"
        ),
        build(:imported_custom_events,
          date: ~D[2022-01-01],
          name: "404",
          path: "/dev/null"
        )
      ])

      key_conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01&with_imported=true"
        )

      assert json_response(key_conn, 200) == [%{"label" => "url", "value" => "url"}]

      filters = Jason.encode!([[:is_not, "event:props:url", ["(none)"]]])

      value_conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/custom-prop-values/url?period=day&date=2022-01-01&with_imported=true&filters=#{filters}"
        )

      assert json_response(value_conn, 200) == [
               %{"label" => "http://example1.com", "value" => "http://example1.com"}
             ]
    end

    for {q, label} <- [{"", "without filter"}, {"g", "with filter"}] do
      test "merges source suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], referrer_source: "Bing"),
          build(:pageview, timestamp: ~N[2019-01-01 23:30:01], referrer_source: "Bing"),
          build(:pageview, timestamp: ~N[2019-01-01 23:40:01], referrer_source: "Bing"),
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], referrer_source: "Google"),
          build(:imported_sources, date: ~D[2019-01-01], source: "Google", pageviews: 3)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/source?period=month&date=2019-01-01&q=#{unquote(q)}&with_imported=true"
          )

        if unquote(label) == "with filter" do
          assert json_response(conn, 200) == [
                   %{"value" => "Google", "label" => "Google"},
                   %{"value" => "Bing", "label" => "Bing"}
                 ]
        else
          assert json_response(conn, 200) == [
                   %{"value" => "Direct / None", "label" => "Direct / None"},
                   %{"value" => "Google", "label" => "Google"},
                   %{"value" => "Bing", "label" => "Bing"}
                 ]
        end
      end

      test "merges channel suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], referrer_source: "Bing"),
          build(:pageview, timestamp: ~N[2019-01-01 23:30:01], referrer_source: "Bing"),
          build(:pageview, timestamp: ~N[2019-01-01 23:40:01], referrer_source: "Bing"),
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], referrer_source: "Google"),
          build(:imported_sources, date: ~D[2019-01-01], channel: "Organic Social", pageviews: 3)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/channel?period=month&date=2019-01-01&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => "Organic Search", "label" => "Organic Search"},
                 %{"value" => "Organic Social", "label" => "Organic Social"}
               ]
      end
    end

    for {q, label} <- [{"", "without filter"}, {"o", "with filter"}] do
      test "merges screen suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], screen_size: "Mobile"),
          build(:pageview, timestamp: ~N[2019-01-01 23:30:01], screen_size: "Mobile"),
          build(:pageview, timestamp: ~N[2019-01-01 23:40:01], screen_size: "Mobile"),
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], screen_size: "Desktop"),
          build(:imported_devices, date: ~D[2019-01-01], device: "Desktop", pageviews: 3)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/screen?period=month&date=2019-01-01&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => "Desktop", "label" => "Desktop"},
                 %{"value" => "Mobile", "label" => "Mobile"}
               ]
      end
    end

    for {q, label} <- [{"", "without filter"}, {"o", "with filter"}] do
      test "merges page suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:30:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:40:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/blog"),
          build(:imported_pages, date: ~D[2019-01-01], page: "/blog", pageviews: 3)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => "/blog", "label" => "/blog"},
                 %{"value" => "/welcome", "label" => "/welcome"}
               ]
      end
    end

    for {q, label} <- [{"", "without filter"}, {"o", "with filter"}] do
      test "merges entry page suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:30:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:40:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/blog"),
          build(:imported_entry_pages, date: ~D[2019-01-01], entry_page: "/blog", pageviews: 3)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/entry_page?period=month&date=2019-01-01&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => "/blog", "label" => "/blog"},
                 %{"value" => "/welcome", "label" => "/welcome"}
               ]
      end
    end

    for {q, label} <- [{"", "without filter"}, {"o", "with filter"}] do
      test "merges exit page suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:30:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:40:01], pathname: "/welcome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/blog"),
          build(:imported_exit_pages, date: ~D[2019-01-01], exit_page: "/blog", pageviews: 3)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/exit_page?period=month&date=2019-01-01&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => "/blog", "label" => "/blog"},
                 %{"value" => "/welcome", "label" => "/welcome"}
               ]
      end
    end

    for {q, label} <- [{"", "without filter"}, {"o", "with filter"}] do
      test "merges browser suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], browser: "Chrome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:30:01], browser: "Chrome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:40:01], browser: "Chrome"),
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], browser: "Firefox"),
          build(:imported_browsers, date: ~D[2019-01-01], browser: "Firefox", pageviews: 3)
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/browser?period=month&date=2019-01-01&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => "Firefox", "label" => "Firefox"},
                 %{"value" => "Chrome", "label" => "Chrome"}
               ]
      end
    end

    for {q, label} <- [{"", "without filter"}, {"i", "with filter"}] do
      test "merges operating system suggestions from native and imported data #{label}", %{
        conn: conn,
        site: site,
        site_import: site_import
      } do
        populate_stats(site, site_import.id, [
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], operating_system: "Linux"),
          build(:pageview, timestamp: ~N[2019-01-01 23:30:01], operating_system: "Linux"),
          build(:pageview, timestamp: ~N[2019-01-01 23:40:01], operating_system: "Linux"),
          build(:pageview, timestamp: ~N[2019-01-01 23:00:01], operating_system: "Windows"),
          build(:imported_operating_systems,
            date: ~D[2019-01-01],
            operating_system: "Windows",
            pageviews: 3
          )
        ])

        conn =
          get(
            conn,
            "/api/stats/#{site.domain}/suggestions/operating_system?period=month&date=2019-01-01&q=#{unquote(q)}&with_imported=true"
          )

        assert json_response(conn, 200) == [
                 %{"value" => "Windows", "label" => "Windows"},
                 %{"value" => "Linux", "label" => "Linux"}
               ]
      end
    end

    test "does not query imported data when a different property is filtered by", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2019-01-01 23:00:01],
          pathname: "/blog",
          operating_system: "Linux"
        ),
        build(:imported_operating_systems, date: ~D[2019-01-01], operating_system: "Windows")
      ])

      filters = Jason.encode!([[:is, "event:page", ["/blog"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/operating_system?period=month&date=2019-01-01&filters=#{filters}&q=&with_imported=true"
        )

      assert json_response(conn, 200) == [%{"value" => "Linux", "label" => "Linux"}]
    end

    test "queries imported data when filtering by the same property", %{
      conn: conn,
      site: site,
      site_import: site_import
    } do
      populate_stats(site, site_import.id, [
        build(:pageview,
          timestamp: ~N[2019-01-01 23:00:01],
          pathname: "/blog",
          operating_system: "Linux"
        ),
        build(:imported_operating_systems, date: ~D[2019-01-01], operating_system: "Windows"),
        build(:imported_operating_systems, date: ~D[2019-01-01], operating_system: "Linux")
      ])

      filters = Jason.encode!([[:is_not, "visit:os", ["Linux"]]])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/operating_system?period=month&date=2019-01-01&filters=#{filters}&q=&with_imported=true"
        )

      assert json_response(conn, 200) == [%{"value" => "Windows", "label" => "Windows"}]
    end
  end
end
