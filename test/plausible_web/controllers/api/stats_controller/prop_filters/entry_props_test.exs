defmodule PlausibleWeb.Api.StatsController.EntryPropsTest do
  use PlausibleWeb.ConnCase
  import Plausible.TestUtils

  describe "visit property breakdown" do
    setup [:create_user, :log_in, :create_new_site]

    visit_props = [
      {:browser, "browsers", ["Chrome", "Firefox", "Safari"]},
      {:screen_size, "screen-sizes", ["Desktop", "Mobile", "Tablet"]},
      {:operating_system, "operating-systems", ["Andoid", "Mac", "Windows"]},
      {:country_code, "countries", ["EE", "GB", "US"]},
      {:referrer_source, "sources", ["DuckDuckGo", "Google", "Twitter"]},
      {:pathname, "entry-pages", ["/a", "/b", "/c"]},
      {:pathname, "exit-pages", ["/a", "/b", "/c"]},
      {:name, "conversions", ["Download", "Signup", "Subscribe"]}
    ]

    for {visit_prop, endpoint, value_variants} <- visit_props do
      setup context do
        visit_prop = unquote(visit_prop)
        endpoint = unquote(endpoint)
        value_variants = unquote(value_variants)

        if endpoint == "conversions" do
          insert_goals(context.site, value_variants)
        end

        Map.put(context, :visit_prop_tuple, {visit_prop, endpoint, value_variants})
      end

      test "returns #{endpoint} with entry_property :is filter", %{site: site} = context do
        {visit_prop, endpoint, [a, b, c]} = context.visit_prop_tuple

        populate_stats(site, [
          build(:pageview, [
            {:user_id, 123},
            {visit_prop, a}
          ]),
          build(:pageview, [
            {:user_id, 123},
            {visit_prop, a},
            {:"meta.key", ["author"]},
            {:"meta.value", ["John Doe"]}
          ]),
          build(:pageview, [
            {visit_prop, b},
            {:"meta.key", ["author"]},
            {:"meta.value", ["John Doe"]}
          ]),
          build(:pageview, [
            {visit_prop, c},
            {:"meta.key", ["author"]},
            {:"meta.value", ["other"]}
          ])
        ])

        filters = Jason.encode!(%{entry_props: %{"author" => "John Doe"}})

        conn =
          get(context.conn, "/api/stats/#{site.domain}/#{endpoint}?period=day&filters=#{filters}")

        {instance_name, metric_name} = names_to_assert(endpoint)
        expected = [%{instance_name => b, metric_name => 1}]

        assert_expected_list_of_maps(expected, json_response(conn, 200))
      end

      test "returns #{endpoint} with entry_property :is_not filter", %{site: site} = context do
        {visit_prop, endpoint, [a, b, c]} = context.visit_prop_tuple

        populate_stats(site, [
          build(:pageview, [
            {:user_id, 123},
            {visit_prop, a},
            {:"meta.key", ["author"]},
            {:"meta.value", ["John Doe"]}
          ]),
          build(:pageview, [
            {:user_id, 123},
            {visit_prop, a},
            {:"meta.key", ["author"]},
            {:"meta.value", ["other"]}
          ]),
          build(:pageview, [
            {visit_prop, b},
            {:"meta.key", ["author"]},
            {:"meta.value", ["other"]}
          ]),
          build(:pageview, [
            {visit_prop, c}
          ])
        ])

        filters = Jason.encode!(%{entry_props: %{"author" => "!John Doe"}})

        conn =
          get(context.conn, "/api/stats/#{site.domain}/#{endpoint}?period=day&filters=#{filters}")

        {instance_name, metric_name} = names_to_assert(endpoint)

        expected = [
          %{instance_name => b, metric_name => 1},
          %{instance_name => c, metric_name => 1}
        ]

        assert_expected_list_of_maps(expected, json_response(conn, 200), sort_by: instance_name)
      end

      test "returns #{endpoint} with entry_property :is (none) filter", %{site: site} = context do
        {visit_prop, endpoint, [a, b, c]} = context.visit_prop_tuple

        populate_stats(site, [
          build(:pageview, [
            {:user_id, 123},
            {visit_prop, a},
            {:"meta.key", ["author"]},
            {:"meta.value", ["John Doe"]}
          ]),
          build(:pageview, [
            {:user_id, 123},
            {visit_prop, a}
          ]),
          build(:pageview, [
            {visit_prop, b},
            {:"meta.key", ["logged_in"]},
            {:"meta.value", ["true"]}
          ]),
          build(:pageview, [
            {visit_prop, c}
          ])
        ])

        filters = Jason.encode!(%{entry_props: %{"author" => "(none)"}})

        conn =
          get(context.conn, "/api/stats/#{site.domain}/#{endpoint}?period=day&filters=#{filters}")

        {instance_name, metric_name} = names_to_assert(endpoint)

        expected = [
          %{instance_name => b, metric_name => 1},
          %{instance_name => c, metric_name => 1}
        ]

        assert_expected_list_of_maps(expected, json_response(conn, 200), sort_by: instance_name)
      end

      test "returns #{endpoint} with entry_property :is_not (none) filter",
           %{site: site} = context do
        {visit_prop, endpoint, [a, b, c]} = context.visit_prop_tuple

        populate_stats(site, [
          build(:pageview, [
            {:user_id, 123},
            {visit_prop, a}
          ]),
          build(:pageview, [
            {:user_id, 123},
            {visit_prop, a},
            {:"meta.key", ["author"]},
            {:"meta.value", ["John Doe"]}
          ]),
          build(:pageview, [
            {visit_prop, b}
          ]),
          build(:pageview, [
            {visit_prop, c},
            {:"meta.key", ["author"]},
            {:"meta.value", ["other"]}
          ])
        ])

        filters = Jason.encode!(%{entry_props: %{"author" => "!(none)"}})

        conn =
          get(context.conn, "/api/stats/#{site.domain}/#{endpoint}?period=day&filters=#{filters}")

        {instance_name, metric_name} = names_to_assert(endpoint)
        expected = [%{instance_name => c, metric_name => 1}]

        assert_expected_list_of_maps(expected, json_response(conn, 200), sort_by: instance_name)
      end
    end
  end

  defp insert_goals(site, value_variants) do
    Enum.each(value_variants, fn variant ->
      insert(:goal, %{domain: site.domain, event_name: variant})
    end)
  end

  defp names_to_assert("countries"), do: {"code", "visitors"}
  defp names_to_assert("entry-pages"), do: {"name", "unique_entrances"}
  defp names_to_assert("exit-pages"), do: {"name", "unique_exits"}
  defp names_to_assert("conversions"), do: {"name", "unique_conversions"}
  defp names_to_assert(_), do: {"name", "visitors"}

  defp assert_expected_list_of_maps(expected_list, actual_list, sort_by: name) do
    assert_expected_list_of_maps(
      Enum.sort_by(expected_list, & &1[name]),
      Enum.sort_by(actual_list, & &1[name])
    )
  end

  defp assert_expected_list_of_maps(expected_list, actual_list) do
    Enum.with_index(expected_list)
    |> Enum.each(fn {expected_map, index} ->
      assert map_subset?(expected_map, Enum.at(actual_list, index))
    end)
  end

  defp map_subset?(m1, m2) do
    MapSet.subset?(MapSet.new(m1), MapSet.new(m2))
  end

  describe "detailed pages breakdown" do
    setup [:create_user, :log_in, :create_new_site]

    setup %{site: site} = context do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 12:00:00]
        ),
        build(:pageview,
          user_id: 123,
          pathname: "/blog/uku-1",
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"],
          timestamp: ~N[2021-01-01 12:10:00]
        ),
        build(:pageview,
          user_id: 456,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 12:00:00]
        ),
        build(:pageview,
          user_id: 456,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 12:10:00]
        ),
        build(:pageview,
          pathname: "/blog",
          timestamp: ~N[2021-01-01 12:00:00]
        ),
        build(:pageview,
          pathname: "/blog/john-1",
          "meta.key": ["author"],
          "meta.value": ["John Doe"],
          timestamp: ~N[2021-01-01 12:00:00]
        )
      ])

      context
    end

    test "calculates bounce_rate and time_on_page with entry_property :is filter",
         %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_props: %{"author" => "John Doe"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) |> Enum.sort_by(& &1["name"]) == [
               %{
                 "name" => "/blog",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
               },
               %{
                 "name" => "/blog/john-1",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 50,
                 "time_on_page" => 600
               }
             ]
    end

    test "calculates bounce_rate and time_on_page with entry_property :is_not filter",
         %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_props: %{"author" => "!John Doe"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) |> Enum.sort_by(& &1["name"]) == [
               %{
                 "name" => "/blog",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 50,
                 "time_on_page" => 600
               },
               %{
                 "name" => "/blog/uku-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
               }
             ]
    end

    test "calculates bounce_rate and time_on_page with entry_property :is (none) filter",
         %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_props: %{"author" => "(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "/blog",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 50,
                 "time_on_page" => 600
               },
               %{
                 "name" => "/blog/uku-1",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
               }
             ]
    end

    test "calculates bounce_rate and time_on_page with entry_property :is_not (none) filter",
         %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_props: %{"author" => "!(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/pages?period=day&date=2021-01-01&filters=#{filters}&detailed=true"
        )

      assert json_response(conn, 200) |> Enum.sort_by(& &1["name"]) == [
               %{
                 "name" => "/blog",
                 "visitors" => 1,
                 "pageviews" => 1,
                 "bounce_rate" => nil,
                 "time_on_page" => nil
               },
               %{
                 "name" => "/blog/john-1",
                 "visitors" => 2,
                 "pageviews" => 2,
                 "bounce_rate" => 50,
                 "time_on_page" => 600
               }
             ]
    end
  end

  describe "main graph and top stats" do
    setup [:create_user, :log_in, :create_new_site]

    setup %{site: site} = context do
      populate_stats(site, [
        build(:pageview,
          timestamp: ~N[2021-01-01 12:00:00]
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 12:00:00],
          "meta.key": ["author"],
          "meta.value": [""]
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 12:00:00],
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          timestamp: ~N[2021-01-01 12:00:00],
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"]
        ),
        build(:pageview,
          user_id: 123,
          timestamp: ~N[2021-01-01 12:00:00] |> Timex.shift(days: 1)
        ),
        build(:pageview,
          user_id: 123,
          timestamp: ~N[2021-01-01 12:10:00] |> Timex.shift(days: 1),
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 456,
          timestamp: ~N[2021-01-01 12:00:00] |> Timex.shift(days: 1),
          "meta.key": ["author"],
          "meta.value": [""]
        ),
        build(:pageview,
          user_id: 456,
          timestamp: ~N[2021-01-01 12:10:00] |> Timex.shift(days: 1),
          "meta.key": ["author"],
          "meta.value": ["Uku Taht"]
        ),
        build(:pageview,
          user_id: 789,
          timestamp: ~N[2021-01-01 12:00:00] |> Timex.shift(days: 1),
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 789,
          timestamp: ~N[2021-01-01 12:10:00] |> Timex.shift(days: 1)
        )
      ])

      context
    end

    test "returns data with entry_property :is filter", %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_props: %{"author" => "John Doe"}})
      custom_period = "period=custom&date=2021-01-01,2021-01-02"

      plot_expected = [1, 1]

      get(conn, "/api/stats/#{site.domain}/main-graph?&#{custom_period}&filters=#{filters}")
      |> assert_main_graph_plot(plot_expected)

      top_stats_expected = [
        %{"change" => 100, "name" => "Unique visitors", "value" => 2},
        %{"change" => 100, "name" => "Total pageviews", "value" => 3},
        %{"change" => nil, "name" => "Bounce rate", "value" => 50},
        %{"change" => 100, "name" => "Visit duration", "value" => 300}
      ]

      get(conn, "/api/stats/#{site.domain}/top-stats?&#{custom_period}&filters=#{filters}")
      |> assert_top_stats(top_stats_expected)
    end

    test "returns data with entry_property :is_not filter", %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_props: %{"author" => "!John Doe"}})
      custom_period = "period=custom&date=2021-01-01,2021-01-02"

      plot_expected = [3, 2]

      get(conn, "/api/stats/#{site.domain}/main-graph?&#{custom_period}&filters=#{filters}")
      |> assert_main_graph_plot(plot_expected)

      top_stats_expected = [
        %{"change" => 100, "name" => "Unique visitors", "value" => 5},
        %{"change" => 100, "name" => "Total pageviews", "value" => 7},
        %{"change" => nil, "name" => "Bounce rate", "value" => 60},
        %{"change" => 100, "name" => "Visit duration", "value" => 240}
      ]

      get(conn, "/api/stats/#{site.domain}/top-stats?&#{custom_period}&filters=#{filters}")
      |> assert_top_stats(top_stats_expected)
    end

    test "returns data with entry_property :is (none) filter", %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_props: %{"author" => "(none)"}})
      custom_period = "period=custom&date=2021-01-01,2021-01-02"

      plot_expected = [1, 1]

      get(conn, "/api/stats/#{site.domain}/main-graph?&#{custom_period}&filters=#{filters}")
      |> assert_main_graph_plot(plot_expected)

      top_stats_expected = [
        %{"change" => 100, "name" => "Unique visitors", "value" => 2},
        %{"change" => 100, "name" => "Total pageviews", "value" => 3},
        %{"change" => nil, "name" => "Bounce rate", "value" => 50},
        %{"change" => 100, "name" => "Visit duration", "value" => 300}
      ]

      get(conn, "/api/stats/#{site.domain}/top-stats?&#{custom_period}&filters=#{filters}")
      |> assert_top_stats(top_stats_expected)
    end

    test "returns data with entry_property :is_not (none) filter", %{conn: conn, site: site} do
      filters = Jason.encode!(%{entry_props: %{"author" => "!(none)"}})
      custom_period = "period=custom&date=2021-01-01,2021-01-02"

      plot_expected = [3, 2]

      get(conn, "/api/stats/#{site.domain}/main-graph?&#{custom_period}&filters=#{filters}")
      |> assert_main_graph_plot(plot_expected)

      top_stats_expected = [
        %{"change" => 100, "name" => "Unique visitors", "value" => 5},
        %{"change" => 100, "name" => "Total pageviews", "value" => 7},
        %{"change" => nil, "name" => "Bounce rate", "value" => 60},
        %{"change" => 100, "name" => "Visit duration", "value" => 240}
      ]

      get(conn, "/api/stats/#{site.domain}/top-stats?&#{custom_period}&filters=#{filters}")
      |> assert_top_stats(top_stats_expected)
    end

    defp assert_main_graph_plot(conn, expected) do
      assert %{"plot" => actual} = json_response(conn, 200)
      assert actual == expected
    end

    defp assert_top_stats(conn, expected) do
      assert %{"top_stats" => actual} = json_response(conn, 200)
      assert actual == expected
    end
  end
end
