defmodule PlausibleWeb.Api.StatsController.SuggestionsTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/suggestions/:filter_name" do
    setup [:create_user, :log_in, :create_site]

    test "returns suggestions for pages without a query", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["/", "/register", "/contact", "/irrelevant"]
    end

    test "returns suggestions for pages with a query", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/page?period=month&date=2019-01-01&q=re")

      assert json_response(conn, 200) == ["/register", "/irrelevant"]
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
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/source?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["10words", "Bing"]
    end

    test "returns suggestions for countries", %{conn: conn, site: site} do
      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/country?period=month&date=2019-01-01&q=Unit"
        )

      assert json_response(conn, 200) == [%{"code" => "US", "name" => "United States"}]
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

      assert json_response(conn, 200) == [%{"code" => "EE-37", "name" => "Harjumaa"}]
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

      assert json_response(conn, 200) == [%{"code" => "591632", "name" => "Kärdla"}]
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
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/screen?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["Desktop"]
    end

    test "returns suggestions for browsers", %{conn: conn, site: site} do
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/browser?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["Chrome"]
    end

    test "returns suggestions for browser versions", %{conn: conn, site: site} do
      filters = Jason.encode!(%{browser: "Chrome"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/browser_version?period=month&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == ["78.0"]
    end

    test "returns suggestions for OS", %{conn: conn, site: site} do
      conn = get(conn, "/api/stats/#{site.domain}/suggestions/os?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["Mac"]
    end

    test "returns suggestions for OS versions", %{conn: conn, site: site} do
      filters = Jason.encode!(%{os: "Mac"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/os_version?period=month&date=2019-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) == ["10.15"]
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
      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/referrer?period=month&date=2019-01-01")

      assert json_response(conn, 200) == ["10words.com/page1"]
    end
  end

  describe "suggestions for props" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns suggestions for prop key with no filter", %{conn: conn, site: site} do
      populate_stats(site, [
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
          "meta.key": ["dark_mode"],
          "meta.value": ["true"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01")

      assert json_response(conn, 200) |> Enum.sort() == ["author", "dark_mode", "logged_in"]
    end

    test "returns suggestions for prop key with value filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["logged_in"],
          "meta.value": ["true"],
          timestamp: ~N[2022-01-01 00:00:00]
        ),
        build(:pageview,
          "meta.key": ["dark_mode"],
          "meta.value": ["true"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!(%{props: %{"": "true"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/prop_key?period=day&date=2022-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) |> Enum.sort() == ["dark_mode", "logged_in"]
    end

    test "returns suggestions for prop value with no filter", %{conn: conn, site: site} do
      populate_stats(site, [
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
          "meta.key": ["dark_mode"],
          "meta.value": ["true"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      conn =
        get(conn, "/api/stats/#{site.domain}/suggestions/prop_value?period=day&date=2022-01-01")

      assert json_response(conn, 200) |> Enum.sort() == ["Uku Taht", "false", "true"]
    end

    test "returns suggestions for prop value with filter on prop key", %{conn: conn, site: site} do
      populate_stats(site, [
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
          "meta.key": ["dark_mode"],
          "meta.value": ["true"],
          timestamp: ~N[2022-01-01 00:00:00]
        )
      ])

      filters = Jason.encode!(%{props: %{author: "!(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/suggestions/prop_value?period=day&date=2022-01-01&filters=#{filters}"
        )

      assert json_response(conn, 200) |> Enum.sort() == ["Uku Taht"]
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

      assert json_response(conn, 400) == %{"error" => "input validation error"}
    end
  end
end
