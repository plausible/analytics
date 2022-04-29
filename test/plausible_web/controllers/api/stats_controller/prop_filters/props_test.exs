defmodule PlausibleWeb.Api.StatsController.PropsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "GET /api/stats/:domain/screen_sizes" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns screen sizes with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop"
        ),
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          screen_size: "Mobile",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          screen_size: "Tablet"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Desktop", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns screen sizes with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          screen_size: "Mobile",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          screen_size: "Tablet"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "!John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/screen-sizes?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Mobile", "visitors" => 1, "percentage" => 50},
               %{"name" => "Tablet", "visitors" => 1, "percentage" => 50}
             ]
    end
  end

  describe "GET /api/stats/:domain/operating_systems" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns operating systems with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          operating_system: "Mac"
        ),
        build(:pageview,
          user_id: 123,
          operating_system: "Mac",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          operating_system: "Android"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Mac", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns operating systems with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          operating_system: "Windows",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          operating_system: "Mac",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          operating_system: "Android"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "!John Doe"}})

      conn =
        get(conn, "/api/stats/#{site.domain}/operating-systems?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Android", "visitors" => 1, "percentage" => 50},
               %{"name" => "Mac", "visitors" => 1, "percentage" => 50}
             ]
    end
  end

  describe "GET /api/stats/:domain/countries" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top countries with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          country_code: "EE"
        ),
        build(:pageview,
          user_id: 123,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          country_code: "GB",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          country_code: "US"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "visitors" => 1,
                 "percentage" => 100
               }
             ]
    end

    test "returns top countries with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          country_code: "GB",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          country_code: "GB"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "!John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 2,
                 "percentage" => 100
               }
             ]
    end

    test "returns top countries with :is (none) filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          country_code: "GB",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:pageview,
          country_code: "GB"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "code" => "GB",
                 "alpha_3" => "GBR",
                 "name" => "United Kingdom",
                 "flag" => "🇬🇧",
                 "visitors" => 2,
                 "percentage" => 100
               }
             ]
    end

    test "returns top countries with :is_not (none) filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          country_code: "EE",
          "meta.key": ["author"],
          "meta.value": [""]
        ),
        build(:pageview,
          country_code: "GB",
          "meta.key": ["logged_in"],
          "meta.value": ["true"]
        ),
        build(:pageview,
          country_code: "GB"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "!(none)"}})
      conn = get(conn, "/api/stats/#{site.domain}/countries?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{
                 "code" => "EE",
                 "alpha_3" => "EST",
                 "name" => "Estonia",
                 "flag" => "🇪🇪",
                 "visitors" => 2,
                 "percentage" => 100
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/browsers" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns top browsers with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          browser: "Chrome"
        ),
        build(:pageview,
          user_id: 123,
          browser: "Chrome",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          browser: "Firefox",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          browser: "Safari"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Chrome", "visitors" => 1, "percentage" => 100}
             ]
    end

    test "returns top browsers with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          browser: "Chrome",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          browser: "Chrome",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          browser: "Firefox",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          browser: "Safari"
        )
      ])

      filters = Jason.encode!(%{props: %{"author" => "!John Doe"}})
      conn = get(conn, "/api/stats/#{site.domain}/browsers?period=day&filters=#{filters}")

      assert json_response(conn, 200) == [
               %{"name" => "Firefox", "visitors" => 1, "percentage" => 50},
               %{"name" => "Safari", "visitors" => 1, "percentage" => 50}
             ]
    end
  end
end
