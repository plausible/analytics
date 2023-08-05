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
      conn = get(conn, "/api/stats/#{site.domain}/suggestions/goal?period=month&date=2019-01-01")

      assert json_response(conn, 200) == []
    end

    test "returns suggestions for sources", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], referrer_source: "Bing"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], referrer_source: "Bing"),
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], referrer_source: "10words")
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/source?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [
               %{"label" => "Bing", "value" => "Bing"},
               %{"label" => "10words", "value" => "10words"}
             ]
    end

    test "returns suggestions for countries", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2019-01-01 23:00:01], pathname: "/", country_code: "US")
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&q=Unit"
        )

      assert json_response(conn, 200) == [%{"value" => "US", "label" => "United States"}]
    end

    test "returns suggestions for regions", %{conn: conn, user: user} do
      {:ok, [site: site]} = create_new_site(%{user: user})

      populate_stats(site, [
        build(:pageview, country_code: "EE", subdivision1_code: "EE-37"),
        build(:pageview, country_code: "EE", subdivision1_code: "EE-39")
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/region?q=Har"
        )

      assert json_response(conn, 200) == [%{"value" => "EE-37", "label" => "Harjumaa"}]
    end

    test "returns suggestions for cities", %{conn: conn, user: user} do
      {:ok, [site: site]} = create_new_site(%{user: user})

      populate_stats(site, [
        build(:pageview, country_code: "EE", subdivision1_code: "EE-37", city_geoname_id: 588_409),
        build(:pageview, country_code: "EE", subdivision1_code: "EE-39", city_geoname_id: 591_632)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/city?q=Kär"
        )

      assert json_response(conn, 200) == [%{"value" => "591632", "label" => "Kärdla"}]
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
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], pathname: "/", screen_size: "Desktop")
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/screen?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [%{"value" => "Desktop", "label" => "Desktop"}]
    end

    test "returns suggestions for browsers", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, timestamp: ~N[2019-01-01 23:00:00], pathname: "/", browser: "Chrome")
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/browser?period=month&date=2019-01-01")

      assert json_response(conn, 200) == [%{"label" => "Chrome", "value" => "Chrome"}]
    end

    test "returns suggestions for browser versions", %{conn: conn, site: site} do
      filters = Jason.encode!(%{browser: "Chrome"})

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
      filters = Jason.encode!(%{os: "Mac"})

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
      filters = Jason.encode!(%{os: "Mac"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/os_version?period=month&date=2019-01-01&filters=#{filters}&q=11"
        )

      assert json_response(conn, 200) == []
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
    setup [:create_user, :log_in, :create_new_site]

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

      filters = Jason.encode!(%{props: %{author: "!(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/prop_value?period=day&date=2022-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"label" => "(none)", "value" => "(none)"},
               %{"label" => "Uku Taht", "value" => "Uku Taht"},
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

      filters = Jason.encode!(%{props: %{author: "!(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/prop_value?period=day&date=2022-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{"label" => "Uku Taht", "value" => "Uku Taht"},
               %{"label" => "Marko Saric", "value" => "Marko Saric"}
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

      filters = Jason.encode!(%{props: %{author: "!(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/prop_value?period=all&date=CLEVER_SECURITY_RESEARCH&filters=#{filters}"
        )

      assert json_response(conn, 400) == %{
               "error" =>
                 "Failed to parse 'date' argument. Only ISO 8601 dates are allowed, e.g. `2019-09-07`, `2020-01-01`"
             }
    end
  end
end
