defmodule Plausible.Stats.QueryParseAndBuildTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  import Plausible.Stats.QueryParser
  import Plausible.AssertMatches

  alias Plausible.Stats.{Query, DateTimeRange, Filters}

  @now DateTime.new!(~D[2021-05-05], ~T[12:30:00], "Etc/UTC")
  @date_range_realtime %DateTimeRange{
    first: DateTime.new!(~D[2021-05-05], ~T[12:25:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-05], ~T[12:30:05], "Etc/UTC")
  }
  @date_range_30m %DateTimeRange{
    first: DateTime.new!(~D[2021-05-05], ~T[12:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-05], ~T[12:30:05], "Etc/UTC")
  }
  @date_range_day %DateTimeRange{
    first: DateTime.new!(~D[2021-05-05], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-05], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_7d %DateTimeRange{
    first: DateTime.new!(~D[2021-04-28], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-04], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_10d %DateTimeRange{
    first: DateTime.new!(~D[2021-04-25], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-04], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_30d %DateTimeRange{
    first: DateTime.new!(~D[2021-04-05], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-04], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_month %DateTimeRange{
    first: DateTime.new!(~D[2021-05-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-31], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_3mo %DateTimeRange{
    first: DateTime.new!(~D[2021-02-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-04-30], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_6mo %DateTimeRange{
    first: DateTime.new!(~D[2020-11-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-04-30], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_year %DateTimeRange{
    first: DateTime.new!(~D[2021-01-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-12-31], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_12mo %DateTimeRange{
    first: DateTime.new!(~D[2020-05-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-04-30], ~T[23:59:59], "Etc/UTC")
  }

  @default_include %{
    imports: false,
    imports_meta: false,
    time_labels: false,
    total_rows: false,
    comparisons: nil,
    legacy_time_on_page_cutoff: nil,
    trim_relative_date_range: false
  }

  setup [:create_user, :create_site]

  setup do
    Plausible.Stats.Query.Test.fix_now(@now)
    :ok
  end

  def check_success(params, site, expected_result, schema_type \\ :public) do
    assert {:ok, result} = parse(site, schema_type, params, @now)

    return_value = Map.take(result, [:preloaded_goals, :revenue_warning, :revenue_currencies])

    result =
      Map.drop(result, [
        :now,
        :input_date_range,
        :preloaded_goals,
        :revenue_warning,
        :revenue_currencies,
        :consolidated_site_ids
      ])

    assert result == expected_result

    return_value
  end

  def check_error(params, site, expected_error_message, schema_type \\ :public) do
    {:error, message} = parse(site, schema_type, params, @now)
    assert message == expected_error_message
  end

  def check_date_range(date_params, site, expected_date_range, schema_type \\ :public) do
    params =
      %{"site_id" => site.domain, "metrics" => ["visitors", "events"]}
      |> Map.merge(date_params)

    expected_parsed =
      %{
        metrics: [:visitors, :events],
        utc_time_range: expected_date_range,
        filters: [],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: @default_include,
        pagination: %{limit: 10_000, offset: 0}
      }

    check_success(params, site, expected_parsed, schema_type)
  end

  def check_goals(query, opts) do
    assert %Query{
             preloaded_goals: preloaded_goals,
             revenue_warning: revenue_warning,
             revenue_currencies: revenue_currencies
           } = query

    assert goal_names(preloaded_goals[:all]) ==
             Enum.sort(Keyword.get(opts, :preloaded_goals)[:all])

    assert goal_names(preloaded_goals[:matching_toplevel_filters]) ==
             Enum.sort(Keyword.get(opts, :preloaded_goals)[:matching_toplevel_filters])

    assert revenue_warning == Keyword.get(opts, :revenue_warning)
    assert revenue_currencies == Keyword.get(opts, :revenue_currencies)
  end

  defp goal_names(goals), do: Enum.map(goals, & &1.display_name) |> Enum.sort()

  describe "metrics" do
    test "valid metrics passed", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "all"
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "fuller list of metrics", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => [
          "visitors",
          "pageviews",
          "visits",
          "events",
          "bounce_rate",
          "visit_duration"
        ],
        "date_range" => "all"
      }

      assert {:ok, query} = Query.parse_and_build(site, :internal, params)

      assert_matches %Query{
                       metrics: [
                         :visitors,
                         :pageviews,
                         :visits,
                         :events,
                         :bounce_rate,
                         :visit_duration
                       ],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "same metric queried multiple times", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["events", "visitors", "visitors"],
        "date_range" => "all"
      }

      assert {:error, "#/metrics: Expected items to be unique but they were not."} =
               Query.parse_and_build(site, :public, params)
    end

    test "no metrics passed", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => [],
        "date_range" => "all"
      }

      assert {:error, "#/metrics: Expected a minimum of 1 items but got 0."} =
               Query.parse_and_build(site, :public, params)
    end
  end

  describe "filters validation" do
    for operation <- [
          :is,
          :is_not,
          :matches_wildcard,
          :matches_wildcard_not,
          :matches,
          :matches_not,
          :contains,
          :contains_not
        ] do
      test "#{operation} filter", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", ["foo"]]
          ]
        }

        assert {:ok, query} = Query.parse_and_build(site, :internal, params)

        assert_matches %Query{
                         metrics: [:visitors],
                         utc_time_range: ^@date_range_day,
                         filters: [
                           [^unquote(operation), "event:name", ["foo"]]
                         ],
                         dimensions: [],
                         order_by: nil,
                         timezone: ^site.timezone,
                         include: ^@default_include,
                         pagination: %{limit: 10_000, offset: 0}
                       } = query
      end

      test "#{operation} filter with invalid clause", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", "foo"]
          ]
        }

        assert {:error, error} = Query.parse_and_build(site, :internal, params)

        assert error ==
                 "#/filters/0: Invalid filter [\"#{unquote(operation)}\", \"event:name\", \"foo\"]"
      end
    end

    for operation <- [:matches_wildcard, :matches_wildcard_not] do
      test "#{operation} is not a valid filter operation in public API", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", ["foo"]]
          ]
        }

        assert {:error, error} = Query.parse_and_build(site, :public, params)

        assert error ==
                 "#/filters/0: Invalid filter [\"#{unquote(operation)}\", \"event:name\", [\"foo\"]]"
      end
    end

    for too_short_filter <- [
          [],
          ["and"],
          ["or"],
          ["and", []],
          ["or", []],
          ["not"],
          ["is_not"],
          ["is_not", "event:name"],
          ["has_done"],
          ["has_not_done"]
        ] do
      test "errors on too short filter #{inspect(too_short_filter)}", %{
        site: site
      } do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            unquote(too_short_filter)
          ]
        }

        assert {:error, error} = Query.parse_and_build(site, :public, params)

        assert error == ~s(#/filters/0: Invalid filter #{inspect(unquote(too_short_filter))})
      end
    end

    valid_filter = ["is", "event:props:foobar", ["value"]]

    for too_long_filter <- [
          ["and", [valid_filter], "extra"],
          ["or", [valid_filter], []],
          ["not", valid_filter, 1],
          Enum.concat(valid_filter, [true])
        ] do
      test "errors on too long filter #{inspect(too_long_filter)}", %{
        site: site
      } do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            unquote(too_long_filter)
          ]
        }

        assert {:error, error} = Query.parse_and_build(site, :public, params)

        assert error == ~s(#/filters/0: Invalid filter #{inspect(unquote(too_long_filter))})
      end
    end

    test "filtering by invalid operation", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["exists?", "event:name", ["foo"]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/filters/0: Invalid filter [\"exists?\", \"event:name\", [\"foo\"]]"
    end

    test "filtering by custom properties", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:props:foobar", ["value"]]
        ]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:is, "event:props:foobar", ["value"]]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    for dimension <- Filters.event_props() do
      if dimension != "goal" do
        test "filtering by event:#{dimension} filter", %{site: site} do
          prefixed_dimension = "event:#{unquote(dimension)}"

          params = %{
            "site_id" => site.domain,
            "metrics" => ["visitors"],
            "date_range" => "all",
            "filters" => [
              ["is", prefixed_dimension, ["foo"]]
            ]
          }

          assert {:ok, query} = Query.parse_and_build(site, :public, params)

          assert_matches %Query{
                           metrics: [:visitors],
                           utc_time_range: ^@date_range_day,
                           filters: [
                             [:is, ^prefixed_dimension, ["foo"]]
                           ],
                           dimensions: [],
                           order_by: nil,
                           timezone: ^site.timezone,
                           include: ^@default_include,
                           pagination: %{limit: 10_000, offset: 0}
                         } = query
        end
      end
    end

    for dimension <- Filters.visit_props() do
      test "filtering by visit:#{dimension} filter", %{site: site} do
        prefixed_dimension = "visit:#{unquote(dimension)}"

        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["is", prefixed_dimension, ["ab"]]
          ]
        }

        assert {:ok, query} = Query.parse_and_build(site, :public, params)

        assert_matches %Query{
                         metrics: [:visitors],
                         utc_time_range: ^@date_range_day,
                         filters: [
                           [:is, ^prefixed_dimension, ["ab"]]
                         ],
                         dimensions: [],
                         order_by: nil,
                         timezone: ^site.timezone,
                         include: ^@default_include,
                         pagination: %{limit: 10_000, offset: 0}
                       } = query
      end
    end

    test "invalid event filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:device", ["foo"]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error == "#/filters/0: Invalid filter [\"is\", \"event:device\", [\"foo\"]]"
    end

    test "invalid visit filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "visit:name", ["foo"]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error == "#/filters/0: Invalid filter [\"is\", \"visit:name\", [\"foo\"]]"
    end

    test "invalid filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => "foobar"
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/filters: Type mismatch. Expected Array but got String."
    end

    test "numeric filter is invalid", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "visit:os_version", [123]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "Invalid filter '[\"is\", \"visit:os_version\", [123]]'."
    end

    test "numbers are valid for visit:city", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "visit:city", [123, 456]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:is, "visit:city", [123, 456]]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "strings are valid for visit:city", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "visit:city", ["123", "456"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:is, "visit:city", ["123", "456"]]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "invalid visit:country filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "visit:country", ["USA"]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid visit:country filter, visit:country needs to be a valid 2-letter country code."
    end

    test "valid nested `not`, `and` and `or`", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          [
            "or",
            [
              [
                "and",
                [
                  ["is", "visit:city_name", ["Tallinn"]],
                  ["is", "visit:country_name", ["Estonia"]]
                ]
              ],
              ["not", ["is", "visit:country_name", ["Estonia"]]]
            ]
          ]
        ]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [
                           :or,
                           [
                             [
                               :and,
                               [
                                 [:is, "visit:city_name", ["Tallinn"]],
                                 [:is, "visit:country_name", ["Estonia"]]
                               ]
                             ],
                             [:not, [:is, "visit:country_name", ["Estonia"]]]
                           ]
                         ]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "valid has_done and has_not_done filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["has_done", ["is", "event:name", ["Signup"]]],
          [
            "has_not_done",
            [
              "or",
              [
                ["is", "event:goal", ["Signup"]],
                ["is", "event:page", ["/signup"]]
              ]
            ]
          ]
        ]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:has_done, [:is, "event:name", ["Signup"]]],
                         [
                           :has_not_done,
                           [
                             :or,
                             [[:is, "event:goal", ["Signup"]], [:is, "event:page", ["/signup"]]]
                           ]
                         ]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "fails when using visit filters within has_done filters", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["has_done", ["is", "visit:browser", ["Chrome"]]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid filters. Behavioral filters (has_done, has_not_done) can only be used with event dimension filters."
    end

    test "fails when nesting behavioral filters", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["has_done", ["has_not_done", ["is", "visit:browser", ["Chrome"]]]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid filters. Behavioral filters (has_done, has_not_done) cannot be nested."
    end

    for operator <- ["not", "or", "has_done", "has_not_done"] do
      test "invalid `#{operator}` clause", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [[unquote(operator), []]]
        }

        assert {:error, error} = Query.parse_and_build(site, :internal, params)
        assert error == "#/filters/0: Invalid filter [\"#{unquote(operator)}\", []]"
      end
    end

    test "event:hostname filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "event:hostname", ["a.plausible.io"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:is, "event:hostname", ["a.plausible.io"]]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "event:hostname filter not at top level is invalid", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["not", ["is", "event:hostname", ["a.plausible.io"]]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid filters. Dimension `event:hostname` can only be filtered at the top level."
    end

    for operation <- [:is, :contains, :is_not, :contains_not] do
      test "#{operation} allows case_sensitive modifier", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [
              Atom.to_string(unquote(operation)),
              "event:page",
              ["/foo"],
              %{"case_sensitive" => false}
            ],
            [
              Atom.to_string(unquote(operation)),
              "event:name",
              ["/foo"],
              %{"case_sensitive" => true}
            ]
          ]
        }

        assert {:ok, query} = Query.parse_and_build(site, :public, params)

        assert_matches %Query{
                         metrics: [:visitors],
                         utc_time_range: ^@date_range_day,
                         filters: [
                           [
                             ^unquote(operation),
                             "event:page",
                             ["/foo"],
                             %{case_sensitive: false}
                           ],
                           [^unquote(operation), "event:name", ["/foo"], %{case_sensitive: true}]
                         ],
                         dimensions: [],
                         order_by: nil,
                         timezone: ^site.timezone,
                         include: ^@default_include,
                         pagination: %{limit: 10_000, offset: 0}
                       } = query
      end
    end

    for operation <- [:matches, :matches_not, :matches_wildcard, :matches_wildcard_not] do
      test "case_sensitive modifier is not valid for #{operation}", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [
              Atom.to_string(unquote(operation)),
              "event:hostname",
              ["a.plausible.io"],
              %{"case_sensitive" => false}
            ]
          ]
        }

        assert {:error, error} = Query.parse_and_build(site, :internal, params)

        assert error ==
                 "#/filters/0: Invalid filter [\"#{unquote(operation)}\", \"event:hostname\", [\"a.plausible.io\"], %{\"case_sensitive\" => false}]"
      end
    end
  end

  describe "preloading goals" do
    setup %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, event_name: "Purchase"})
      insert(:goal, %{site: site, event_name: "Contact"})

      :ok
    end

    test "with exact match", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup", "Purchase"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:goal", ["Signup", "Purchase"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Contact", "Purchase", "Signup"],
          matching_toplevel_filters: ["Purchase", "Signup"]
        },
        revenue_currencies: %{}
      )
    end

    test "with case insensitive match", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["signup", "purchase"], %{"case_sensitive" => false}]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:is, "event:goal", ["signup", "purchase"], %{case_sensitive: false}]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Contact", "Purchase", "Signup"],
          matching_toplevel_filters: ["Purchase", "Signup"]
        },
        revenue_currencies: %{}
      )
    end

    test "with contains match", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["contains", "event:goal", ["Sign", "pur"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [[:contains, "event:goal", ["Sign", "pur"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Contact", "Purchase", "Signup"],
          matching_toplevel_filters: ["Signup"]
        },
        revenue_currencies: %{}
      )
    end

    test "with case insensitive contains match", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["contains", "event:goal", ["sign", "CONT"], %{"case_sensitive" => false}]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:contains, "event:goal", ["sign", "CONT"], %{case_sensitive: false}]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Contact", "Purchase", "Signup"],
          matching_toplevel_filters: ["Contact", "Signup"]
        },
        revenue_currencies: %{}
      )
    end
  end

  describe "include validation" do
    test "setting include values", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["time"],
        "include" => %{"imports" => true, "time_labels" => true, "total_rows" => true}
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["time"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: %{
                         imports: true,
                         imports_meta: false,
                         time_labels: true,
                         total_rows: true,
                         comparisons: nil,
                         legacy_time_on_page_cutoff: nil,
                         trim_relative_date_range: false
                       },
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "setting invalid imports value", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => "foobar"
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/include: Type mismatch. Expected Object but got String."
    end

    test "setting include.time_labels without time dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"time_labels" => true}
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "Invalid include.time_labels: requires a time dimension."
    end
  end

  describe "include.comparisons" do
    test "not allowed in public API", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"comparisons" => %{"mode" => "previous_period"}}
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/include/comparisons: Schema does not allow additional properties."
    end

    test "mode=previous_period", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"comparisons" => %{"mode" => "previous_period"}}
      }

      assert {:ok, query} = Query.parse_and_build(site, :internal, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: %{
                         comparisons: %{
                           mode: "previous_period"
                         },
                         imports: false,
                         imports_meta: false,
                         time_labels: false,
                         total_rows: false,
                         legacy_time_on_page_cutoff: nil,
                         trim_relative_date_range: false
                       },
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "mode=year_over_year", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"comparisons" => %{"mode" => "year_over_year"}}
      }

      assert {:ok, query} = Query.parse_and_build(site, :internal, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: %{
                         comparisons: %{
                           mode: "year_over_year"
                         },
                         imports: false,
                         imports_meta: false,
                         time_labels: false,
                         total_rows: false,
                         legacy_time_on_page_cutoff: nil,
                         trim_relative_date_range: false
                       },
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "mode=custom", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{
          "comparisons" => %{"mode" => "custom", "date_range" => ["2021-04-05", "2021-05-04"]}
        }
      }

      assert {:ok, query} = Query.parse_and_build(site, :internal, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: %{
                         comparisons: %{
                           mode: "custom",
                           date_range: ^@date_range_30d
                         },
                         imports_meta: false,
                         imports: false,
                         time_labels: false,
                         total_rows: false,
                         legacy_time_on_page_cutoff: nil,
                         trim_relative_date_range: false
                       },
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "mode=custom without date_range is invalid", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"comparisons" => %{"mode" => "custom"}}
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)

      assert error ==
               "#/include/comparisons: Expected exactly one of the schemata to match, but none of them did."
    end

    test "mode=previous_period with date_range is invalid", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{
          "comparisons" => %{
            "mode" => "previous_period",
            "date_range" => ["2024-01-01", "2024-01-31"]
          }
        }
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)

      assert error ==
               "#/include/comparisons: Expected exactly one of the schemata to match, but none of them did."
    end
  end

  describe "pagination validation" do
    test "setting pagination values", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["time"],
        "pagination" => %{"limit" => 100, "offset" => 200}
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["time"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 100, offset: 200}
                     } = query
    end

    test "out of range limit value", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "pagination" => %{"limit" => 100_000}
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/pagination/limit: Expected the value to be <= 10000"
    end

    test "out of range offset value", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "pagination" => %{"offset" => -5}
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/pagination/offset: Expected the value to be >= 0"
    end
  end

  describe "event:goal filter validation" do
    test "valid filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/thank-you"})

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:goal", ["Signup", "Visit /thank-you"]]
        ]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:is, "event:goal", ["Signup", "Visit /thank-you"]]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Signup", "Visit /thank-you"],
          matching_toplevel_filters: ["Signup", "Visit /thank-you"]
        },
        revenue_warning: nil,
        revenue_currencies: %{}
      )
    end

    test "invalid event filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:goal", ["Signup"]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid filters. The goal `Signup` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
    end

    test "invalid page filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:goal", ["Visit /thank-you"]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid filters. The goal `Visit /thank-you` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
    end

    test "unsupported filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is_not", "event:goal", ["Signup"]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error == "#/filters/0: Invalid filter [\"is_not\", \"event:goal\", [\"Signup\"]]"
    end

    test "not top-level filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          [
            "or",
            [
              ["is", "event:goal", ["Signup"]],
              ["is", "event:name", ["pageview"]]
            ]
          ]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid filters. Dimension `event:goal` can only be filtered at the top level."
    end

    test "allowed within behavioral filters has_done", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          [
            "has_done",
            [
              "or",
              [
                ["is", "event:goal", ["Signup"]],
                ["is", "event:name", ["pageview"]]
              ]
            ]
          ]
        ]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [
                           :has_done,
                           [
                             :or,
                             [
                               [:is, "event:goal", ["Signup"]],
                               [:is, "event:name", ["pageview"]]
                             ]
                           ]
                         ]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{all: ["Signup"], matching_toplevel_filters: ["Signup"]},
        revenue_warning: nil,
        revenue_currencies: %{}
      )
    end

    test "name is checked even within behavioral filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["has_done", ["is", "event:goal", ["Unknown"]]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)

      assert error ==
               "Invalid filters. The goal `Unknown` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
    end
  end

  describe "date range validation" do
    for {shortcut, expected_date_range} <- [
          {"day", @date_range_day},
          {"7d", @date_range_7d},
          {"10d", @date_range_10d},
          {"30d", @date_range_30d},
          {"month", @date_range_month},
          {"3mo", @date_range_3mo},
          {"6mo", @date_range_6mo},
          {"12mo", @date_range_12mo},
          {"year", @date_range_year}
        ] do
      test "parses '#{shortcut}' date_range shortcut ", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "events"],
          "date_range" => unquote(shortcut)
        }

        assert {:ok, query} = Query.parse_and_build(site, :public, params)

        assert_matches %Query{
                         metrics: [:visitors, :events],
                         utc_time_range: ^unquote(Macro.escape(expected_date_range)),
                         filters: [],
                         dimensions: [],
                         order_by: nil,
                         timezone: ^site.timezone,
                         include: ^@default_include,
                         pagination: %{limit: 10_000, offset: 0}
                       } = query
      end
    end

    for {shortcut, expected_date_range} <- [
          {"30m", @date_range_30m},
          {"realtime", @date_range_realtime}
        ] do
      test "'#{shortcut}' shortcut is available only in the internal API schema", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors", "events"],
          "date_range" => unquote(shortcut)
        }

        assert {:ok, query} = Query.parse_and_build(site, :internal, params)

        assert_matches %Query{
                         metrics: [:visitors, :events],
                         utc_time_range: ^unquote(Macro.escape(expected_date_range)),
                         filters: [],
                         dimensions: [],
                         order_by: nil,
                         timezone: ^site.timezone,
                         include: ^@default_include,
                         pagination: %{limit: 10_000, offset: 0}
                       } = query

        assert {:error, error} = Query.parse_and_build(site, :public, params)
        assert error == "#/date_range: Invalid date range \"#{unquote(shortcut)}\""
      end
    end

    test "parsing `all` with previous data", %{site: site} do
      site = Map.put(site, :stats_start_date, ~D[2020-01-01])
      expected_date_range = DateTimeRange.new!(~D[2020-01-01], ~D[2021-05-05], "Etc/UTC")

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "all"
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^expected_date_range,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "parsing `all` with no previous data", %{site: site} do
      site = Map.put(site, :stats_start_date, nil)

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "all"
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "parsing custom date range from simple date strings", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => ["2021-05-05", "2021-05-05"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "parsing custom date range from iso8601 timestamps", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => ["2024-01-01T00:00:00Z", "2024-01-02T23:59:59Z"]
      }

      expected_utc_time_range =
        DateTimeRange.new!(
          DateTime.new!(~D[2024-01-01], ~T[00:00:00], "Etc/UTC"),
          DateTime.new!(~D[2024-01-02], ~T[23:59:59], "Etc/UTC")
        )

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^expected_utc_time_range,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "parsing custom date range from iso8601 timestamps with non-UTC timezone", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => ["2024-08-29T07:12:34-07:00", "2024-08-29T10:12:34-07:00"]
      }

      expected_utc_time_range =
        DateTimeRange.new!(~U[2024-08-29 14:12:34Z], ~U[2024-08-29 17:12:34Z])

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^expected_utc_time_range,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    for invalid_value <- ["-1d", "foo", ["21415-00", "eee"]] do
      test "errors on invalid date range value (#{inspect(invalid_value)})", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "date_range" => unquote(invalid_value),
          "metrics" => ["visitors"]
        }

        assert {:error, error} = Query.parse_and_build(site, :public, params)

        assert error == "#/date_range: Invalid date range #{inspect(unquote(invalid_value))}"
      end
    end

    test "999999999mo is invalid date range", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "date_range" => "999999999mo",
        "metrics" => ["visitors"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error == "Invalid date_range \"999999999mo\""
    end

    test "custom date range is invalid when timestamps do not include timezone info", %{
      site: site
    } do
      params = %{
        "site_id" => site.domain,
        "date_range" => ["2021-02-03T00:00:00", "2021-02-03T23:59:59"],
        "metrics" => ["visitors"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error == "Invalid date_range '[\"2021-02-03T00:00:00\", \"2021-02-03T23:59:59\"]'."
    end

    test "custom date range is invalid when timestamp timezone is invalid", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "date_range" => ["2021-02-03T00:00:00-25:00", "2021-02-03T23:59:59-25:00"],
        "metrics" => ["visitors"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "#/date_range: Invalid date range [\"2021-02-03T00:00:00-25:00\", \"2021-02-03T23:59:59-25:00\"]"
    end

    test "custom date range is invalid when date and timestamp are combined", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "date_range" => ["2021-02-03T00:00:00Z", "2021-02-04"],
        "metrics" => ["visitors"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "#/date_range: Invalid date range [\"2021-02-03T00:00:00Z\", \"2021-02-04\"]"
    end

    test "parses date_range relative to date param", %{site: site} do
      date = @now |> DateTime.to_date() |> Date.to_string()

      for {date_range_shortcut, expected_date_range} <- [
            {"day", @date_range_day},
            {"7d", @date_range_7d},
            {"10d", @date_range_10d},
            {"30d", @date_range_30d},
            {"month", @date_range_month},
            {"3mo", @date_range_3mo},
            {"6mo", @date_range_6mo},
            {"12mo", @date_range_12mo},
            {"year", @date_range_year}
          ] do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => date_range_shortcut,
          "date" => date
        }

        assert {:ok, query} = Query.parse_and_build(site, :internal, params)

        assert_matches %Query{
                         metrics: [:visitors],
                         utc_time_range: ^expected_date_range,
                         filters: [],
                         dimensions: [],
                         order_by: nil,
                         timezone: ^site.timezone,
                         include: ^@default_include,
                         pagination: %{limit: 10_000, offset: 0}
                       } = query
      end
    end

    test "date parameter is not available in the public API", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "month",
        "date" => "2021-05-05"
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/date: Schema does not allow additional properties."
    end

    test "parses date_range.first into a datetime right after the gap in site.timezone", %{
      site: site
    } do
      site = %{site | timezone: "America/Santiago"}

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => ["2022-09-11", "2022-09-11"]
      }

      expected_utc_time_range =
        DateTimeRange.new!(~U[2022-09-11 04:00:00Z], ~U[2022-09-12 02:59:59Z])

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^expected_utc_time_range,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "parses date_range.first into the latest of ambiguous datetimes in site.timezone", %{
      site: site
    } do
      site = %{site | timezone: "America/Havana"}

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => ["2023-11-05", "2023-11-05"]
      }

      expected_utc_time_range =
        DateTimeRange.new!(~U[2023-11-05 05:00:00Z], ~U[2023-11-06 04:59:59Z])

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^expected_utc_time_range,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "parses date_range.last into the earliest of ambiguous datetimes in site.timezone", %{
      site: site
    } do
      site = %{site | timezone: "America/Asuncion"}

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => ["2024-03-23", "2024-03-23"]
      }

      expected_utc_time_range =
        DateTimeRange.new!(~U[2024-03-23 03:00:00Z], ~U[2024-03-24 02:59:59Z])

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^expected_utc_time_range,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end
  end

  describe "dimensions validation" do
    for dimension <- Filters.event_props() do
      test "event:#{dimension} dimension", %{site: site} do
        prefixed_dimension = "event:#{unquote(dimension)}"

        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => [prefixed_dimension]
        }

        assert {:ok, query} = Query.parse_and_build(site, :public, params)

        assert_matches %Query{
                         metrics: [:visitors],
                         utc_time_range: ^@date_range_day,
                         filters: [],
                         dimensions: [^prefixed_dimension],
                         order_by: nil,
                         timezone: ^site.timezone,
                         include: ^@default_include,
                         pagination: %{limit: 10_000, offset: 0}
                       } = query
      end
    end

    for dimension <- Filters.visit_props() do
      test "visit:#{dimension} dimension", %{site: site} do
        prefixed_dimension = "visit:#{unquote(dimension)}"

        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => [prefixed_dimension]
        }

        assert {:ok, query} = Query.parse_and_build(site, :public, params)

        assert_matches %Query{
                         metrics: [:visitors],
                         utc_time_range: ^@date_range_day,
                         filters: [],
                         dimensions: [^prefixed_dimension],
                         order_by: nil,
                         timezone: ^site.timezone,
                         include: ^@default_include,
                         pagination: %{limit: 10_000, offset: 0}
                       } = query
      end
    end

    test "time:minute dimension fails public schema validation", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["time:minute"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/dimensions/0: Invalid dimension \"time:minute\""
    end

    test "time:minute dimension passes internal schema validation", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["time:minute"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :internal, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["time:minute"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "custom properties dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:foobar"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["event:props:foobar"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "invalid custom property dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/dimensions/0: Invalid dimension \"event:props:\""
    end

    test "invalid dimension name passed", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visitors"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/dimensions/0: Invalid dimension \"visitors\""
    end

    test "invalid dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => "foobar"
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/dimensions: Type mismatch. Expected Array but got String."
    end

    test "dimensions are not unique", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name", "event:name"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/dimensions: Expected items to be unique but they were not."
    end
  end

  describe "order_by validation" do
    test "ordering by metric", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "all",
        "order_by" => [["events", "desc"], ["visitors", "asc"]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: [{:events, :desc}, {:visitors, :asc}],
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "ordering by dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name"],
        "order_by" => [["event:name", "desc"]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["event:name"],
                       order_by: [{"event:name", :desc}],
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "ordering by invalid value", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["visssss", "desc"]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "#/order_by/0/0: Invalid value in order_by \"visssss\""
    end

    test "ordering by not queried metric", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["events", "desc"]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid order_by entry '{:events, :desc}'. Entry is not a queried metric or dimension."
    end

    test "ordering by not queried dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["event:name", "desc"]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid order_by entry '{\"event:name\", :desc}'. Entry is not a queried metric or dimension."
    end
  end

  describe "custom props access" do
    test "filters - no access", %{site: site, user: user} do
      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.StatsAPI])

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["not", ["is", "event:props:foobar", ["foo"]]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "The owner of this site does not have access to the custom properties feature."
    end

    test "dimensions - no access", %{site: site, user: user} do
      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.StatsAPI])

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:foobar"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "The owner of this site does not have access to the custom properties feature."
    end
  end

  describe "conversion_rate metric" do
    test "fails validation on its own", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all"
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Metric `conversion_rate` can only be queried with event:goal filters or dimensions."
    end

    test "succeeds with event:goal filter", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, event_name: "Purchase", currency: "USD"})

      params = %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:conversion_rate],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:goal", ["Signup"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Purchase", "Signup"],
          matching_toplevel_filters: ["Signup"]
        },
        revenue_currencies: %{}
      )
    end

    test "succeeds with event:goal dimension", %{site: site} do
      insert(:goal, %{site: site, event_name: "Purchase", currency: "USD"})
      insert(:goal, %{site: site, event_name: "Signup"})

      params = %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["event:goal"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:conversion_rate],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["event:goal"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Purchase", "Signup"],
          matching_toplevel_filters: ["Purchase", "Signup"]
        },
        revenue_currencies: %{}
      )
    end

    test "custom properties filter with special metric", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate", "group_conversion_rate"],
        "date_range" => "all",
        "filters" => [["is", "event:props:foo", ["bar"]]],
        "dimensions" => ["event:goal"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:conversion_rate, :group_conversion_rate],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:is, "event:props:foo", ["bar"]]
                       ],
                       dimensions: ["event:goal"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "not top level custom properties filter with special metric is invalid", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate", "group_conversion_rate"],
        "date_range" => "all",
        "filters" => [["not", ["is", "event:props:foo", ["bar"]]]],
        "dimensions" => ["event:goal"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid filters. When `conversion_rate` or `group_conversion_rate` metrics are used, custom property filters can only be used on top level."
    end
  end

  describe "exit_rate metric" do
    test "fails validation without visit:exit_page dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["exit_rate"],
        "date_range" => "all"
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)

      assert error ==
               "Metric `exit_rate` requires a `\"visit:exit_page\"` dimension. No other dimensions are allowed."
    end

    test "fails validation with event only filters", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["exit_rate"],
        "dimensions" => ["visit:exit_page"],
        "filters" => [["is", "event:page", ["/"]]],
        "date_range" => "all"
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)
      assert error == "Metric `exit_rate` cannot be queried when filtering on event dimensions."
    end

    test "fails validation with event metrics", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["exit_rate", "pageviews"],
        "dimensions" => ["visit:exit_page"],
        "date_range" => "all"
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)

      assert error ==
               "Event metric(s) `pageviews` cannot be queried along with session dimension(s) `visit:exit_page`"
    end

    test "passes validation", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["exit_rate"],
        "dimensions" => ["visit:exit_page"],
        "date_range" => "all"
      }

      assert {:ok, query} = Query.parse_and_build(site, :internal, params)

      assert_matches %Query{
                       metrics: [:exit_rate],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["visit:exit_page"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end
  end

  describe "scroll_depth metric" do
    test "fails validation on its own", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["scroll_depth"],
        "date_range" => "all"
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)

      assert error ==
               "Metric `scroll_depth` can only be queried with event:page filters or dimensions."
    end

    test "fails with only a non-top-level event:page filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["scroll_depth"],
        "date_range" => "all",
        "filters" => [["not", ["is", "event:page", ["/"]]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)

      assert error ==
               "Metric `scroll_depth` can only be queried with event:page filters or dimensions."
    end

    test "succeeds with top-level event:page filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["scroll_depth"],
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :internal, params)

      assert_matches %Query{
                       metrics: [:scroll_depth],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:page", ["/"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "succeeds with event:page dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["scroll_depth"],
        "date_range" => "all",
        "dimensions" => ["event:page"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :internal, params)

      assert_matches %Query{
                       metrics: [:scroll_depth],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["event:page"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end
  end

  describe "views_per_visit metric" do
    test "succeeds with normal filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      params = %{
        "site_id" => site.domain,
        "metrics" => ["views_per_visit"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:views_per_visit],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:goal", ["Signup"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{all: ["Signup"], matching_toplevel_filters: ["Signup"]},
        revenue_currencies: %{}
      )
    end

    test "fails validation if event:page filter specified", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["views_per_visit"],
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "Metric `views_per_visit` cannot be queried with a filter on `event:page`."
    end

    test "fails validation with dimensions", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["views_per_visit"],
        "date_range" => "all",
        "dimensions" => ["event:name"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "Metric `views_per_visit` cannot be queried with `dimensions`."
    end
  end

  describe "time_on_page metric" do
    test "fails validation on its own", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["time_on_page"],
        "date_range" => "all"
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Metric `time_on_page` can only be queried with event:page filters or dimensions."
    end

    test "succeeds with event:page dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["time_on_page"],
        "date_range" => "all",
        "dimensions" => ["time", "event:page"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:time_on_page],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["time", "event:page"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "succeeds with event:page filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["time_on_page"],
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:time_on_page],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:page", ["/"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "fails when using only a behavioral filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["time_on_page"],
        "date_range" => "all",
        "filters" => [
          ["has_done", ["is", "event:page", ["/"]]]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :internal, params)

      assert error ==
               "Metric `time_on_page` can only be queried with event:page filters or dimensions."
    end
  end

  describe "revenue metrics" do
    @describetag :ee_only

    setup %{user: user} do
      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.RevenueGoals])
      :ok
    end

    test "can request", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all"
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:total_revenue, :average_revenue],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: [],
          matching_toplevel_filters: []
        },
        revenue_warning: :no_revenue_goals_matching,
        revenue_currencies: %{}
      )
    end

    test "no access" do
      user = new_user()
      site = new_site(owner: user)

      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.StatsAPI])

      params = %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all"
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "The owner of this site does not have access to the revenue metrics feature."
    end

    test "with event:goal filters with same currency", %{site: site} do
      insert(:goal,
        site: site,
        event_name: "Purchase",
        currency: "USD",
        display_name: "PurchaseUSD"
      )

      insert(:goal, site: site, event_name: "Subscription", currency: "USD")
      insert(:goal, site: site, event_name: "Signup")
      insert(:goal, site: site, event_name: "Logout")

      params = %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["PurchaseUSD", "Signup", "Subscription"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:total_revenue, :average_revenue],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:goal", ["PurchaseUSD", "Signup", "Subscription"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["PurchaseUSD", "Signup", "Subscription", "Logout"],
          matching_toplevel_filters: ["PurchaseUSD", "Signup", "Subscription"]
        },
        revenue_warning: nil,
        revenue_currencies: %{default: :USD}
      )
    end

    test "with event:goal filters with different currencies", %{site: site} do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Subscription", currency: "EUR")
      insert(:goal, site: site, event_name: "Signup")

      params = %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Purchase", "Signup", "Subscription"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:total_revenue, :average_revenue],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:goal", ["Purchase", "Signup", "Subscription"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Purchase", "Signup", "Subscription"],
          matching_toplevel_filters: ["Purchase", "Signup", "Subscription"]
        },
        revenue_warning: :no_single_revenue_currency,
        revenue_currencies: %{}
      )
    end

    test "with event:goal filters with no revenue currencies", %{site: site} do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Subscription", currency: "EUR")
      insert(:goal, site: site, event_name: "Signup")

      params = %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:total_revenue, :average_revenue],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:goal", ["Signup"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Purchase", "Subscription", "Signup"],
          matching_toplevel_filters: ["Signup"]
        },
        revenue_warning: :no_revenue_goals_matching,
        revenue_currencies: %{}
      )
    end

    test "with event:goal dimension, different currencies", %{site: site} do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Donation", currency: "EUR")
      insert(:goal, site: site, event_name: "Signup")

      params = %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "dimensions" => ["event:goal"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:total_revenue, :average_revenue],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["event:goal"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Donation", "Purchase", "Signup"],
          matching_toplevel_filters: ["Donation", "Purchase", "Signup"]
        },
        revenue_warning: nil,
        revenue_currencies: %{"Donation" => :EUR, "Purchase" => :USD}
      )
    end

    test "with event:goal dimension and filters", %{site: site} do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Subscription", currency: "EUR")
      insert(:goal, site: site, event_name: "Signup")
      insert(:goal, site: site, event_name: "Logout")

      params = %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "dimensions" => ["event:goal"],
        "filters" => [["is", "event:goal", ["Purchase", "Signup", "Subscription"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:total_revenue, :average_revenue],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:goal", ["Purchase", "Signup", "Subscription"]]],
                       dimensions: ["event:goal"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Logout", "Purchase", "Signup", "Subscription"],
          matching_toplevel_filters: ["Purchase", "Signup", "Subscription"]
        },
        revenue_warning: nil,
        revenue_currencies: %{"Purchase" => :USD, "Subscription" => :EUR}
      )
    end

    test "with event:goal dimension and filters with no revenue goals matching", %{
      site: site
    } do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Subscription", currency: "USD")
      insert(:goal, site: site, event_name: "Signup")
      insert(:goal, site: site, event_name: "Logout")

      params = %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "dimensions" => ["event:goal"],
        "filters" => [["is", "event:goal", ["Signup"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:total_revenue, :average_revenue],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:goal", ["Signup"]]],
                       dimensions: ["event:goal"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query

      check_goals(query,
        preloaded_goals: %{
          all: ["Logout", "Signup", "Subscription", "Purchase"],
          matching_toplevel_filters: ["Signup"]
        },
        revenue_warning: :no_revenue_goals_matching,
        revenue_currencies: %{}
      )
    end
  end

  @tag :ce_build_only
  test "revenue metrics are not available on CE", %{site: site} do
    params = %{
      "site_id" => site.domain,
      "metrics" => ["total_revenue", "average_revenue"],
      "date_range" => "all"
    }

    assert {:error, error} = Query.parse_and_build(site, :public, params)

    assert error ==
             "#/metrics/0: Invalid metric \"total_revenue\"\n#/metrics/1: Invalid metric \"average_revenue\""
  end

  describe "session metrics" do
    test "single session metric succeeds", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "dimensions" => ["visit:device"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:bounce_rate],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["visit:device"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "fails if using session metric with event dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "dimensions" => ["event:props:foo"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Session metric(s) `bounce_rate` cannot be queried along with event dimension(s) `event:props:foo`"
    end

    test "fails if using event metric with session-only dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["events"],
        "date_range" => "all",
        "dimensions" => ["visit:exit_page"]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Event metric(s) `events` cannot be queried along with session dimension(s) `visit:exit_page`"
    end

    test "does not fail if using session metric with event:page dimension", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "dimensions" => ["event:page"]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:bounce_rate],
                       utc_time_range: ^@date_range_day,
                       filters: [],
                       dimensions: ["event:page"],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "does not fail if using session metric with event filter", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "filters" => [["is", "event:props:foo", ["(none)"]]]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:bounce_rate],
                       utc_time_range: ^@date_range_day,
                       filters: [[:is, "event:props:foo", ["(none)"]]],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end
  end

  describe "filtering with segments" do
    test "parsing fails when too many segments in query", %{
      user: user,
      site: site
    } do
      segments =
        insert_list(11, :segment,
          type: :site,
          owner: user,
          site: site,
          name: "any"
        )

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["and", segments |> Enum.map(fn segment -> ["is", "segment", [segment.id]] end)]
        ]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error == "Invalid filters. You can only use up to 10 segment filters in a query."
    end

    test "parsing fails when segment filter is used, but segment is from another site", %{
      site: site
    } do
      other_user = new_user()
      other_site = new_site(owner: other_user)

      segment =
        insert(:segment,
          type: :site,
          owner: other_user,
          site: other_site,
          name: "any"
        )

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "segment", [segment.id]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error == "Invalid filters. Some segments don't exist or aren't accessible."
    end

    test "hiding custom properties filters in segments doesn't allow bypasssing feature check",
         %{
           site: site,
           user: user
         } do
      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.StatsAPI])

      segment =
        insert(:segment,
          type: :site,
          owner: user,
          site: site,
          name: "segment with custom props filter",
          segment_data: %{"filters" => [["is", "event:props:foobar", ["foo"]]]}
        )

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "segment", [segment.id]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "The owner of this site does not have access to the custom properties feature."
    end

    test "querying conversion rate is illegal if the complex event:goal filter is within a segment",
         %{
           site: site,
           user: user
         } do
      segment =
        insert(:segment,
          type: :site,
          owner: user,
          site: site,
          name: "any",
          segment_data: %{
            "filters" => [
              [
                "or",
                [
                  ["is", "event:goal", ["Signup"]],
                  ["contains", "event:page", ["/"]]
                ]
              ]
            ]
          }
        )

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "conversion_rate"],
        "date_range" => "all",
        "filters" => [["is", "segment", [segment.id]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)

      assert error ==
               "Invalid filters. Dimension `event:goal` can only be filtered at the top level."
    end

    test "resolves segments correctly", %{site: site, user: user} do
      emea_segment =
        insert(:segment,
          type: :site,
          owner: user,
          site: site,
          name: "EMEA",
          segment_data: %{
            "filters" => [["is", "visit:country", ["FR", "DE"]]],
            "labels" => %{"FR" => "France", "DE" => "Germany"}
          }
        )

      apac_segment =
        insert(:segment,
          type: :site,
          owner: user,
          site: site,
          name: "APAC",
          segment_data: %{
            "filters" => [["is", "visit:country", ["AU", "NZ"]]],
            "labels" => %{"AU" => "Australia", "NZ" => "New Zealand"}
          }
        )

      firefox_segment =
        insert(:segment,
          type: :site,
          owner: user,
          site: site,
          name: "APAC",
          segment_data: %{
            "filters" => [
              ["is", "visit:browser", ["Firefox"]],
              ["is", "visit:os", ["Linux"]]
            ]
          }
        )

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "all",
        "filters" => [
          [
            "and",
            [
              ["is", "segment", [apac_segment.id, emea_segment.id]],
              ["is", "segment", [firefox_segment.id]]
            ]
          ]
        ]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [
                           :or,
                           [
                             [:and, [[:is, "visit:country", ["AU", "NZ"]]]],
                             [:and, [[:is, "visit:country", ["FR", "DE"]]]]
                           ]
                         ],
                         [
                           :and,
                           [
                             [:is, "visit:browser", ["Firefox"]],
                             [:is, "visit:os", ["Linux"]]
                           ]
                         ]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "resolves segments containing otherwise internal features", %{site: site, user: user} do
      insert(:goal, %{site: site, event_name: "Signup"})

      segment_from_dashboard =
        insert(:segment,
          name: "A segment that contains :internal features",
          type: :site,
          owner: user,
          site: site,
          segment_data: %{
            "filters" => [["has_not_done", ["is", "event:goal", ["Signup"]]]]
          }
        )

      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "all",
        "filters" => [
          ["is", "segment", [segment_from_dashboard.id]]
        ]
      }

      assert {:ok, query} = Query.parse_and_build(site, :public, params)

      assert_matches %Query{
                       metrics: [:visitors, :events],
                       utc_time_range: ^@date_range_day,
                       filters: [
                         [:has_not_done, [:is, "event:goal", ["Signup"]]]
                       ],
                       dimensions: [],
                       order_by: nil,
                       timezone: ^site.timezone,
                       include: ^@default_include,
                       pagination: %{limit: 10_000, offset: 0}
                     } = query
    end

    test "validation fails with string segment ids", %{site: site} do
      params = %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "segment", ["123"]]]
      }

      assert {:error, error} = Query.parse_and_build(site, :public, params)
      assert error == "Invalid filter '[\"is\", \"segment\", [\"123\"]]'."
    end
  end

  on_ee do
    describe "query.consolidated_site_ids" do
      test "is set to nil when site is regular", %{site: site} do
        params = %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all"
        }

        {:ok, %{consolidated_site_ids: nil}} = Query.parse_and_build(site, :public, params)
        {:ok, %{consolidated_site_ids: nil}} = Query.parse_and_build(site, :internal, params)
      end

      test "is set to a list of site_ids when site is consolidated", %{site: site} do
        new_site(team: site.team)
        cv = new_consolidated_view(site.team)

        params = %{
          "site_id" => cv.domain,
          "metrics" => ["visitors"],
          "date_range" => "all"
        }

        assert {:ok, %{consolidated_site_ids: site_ids}} =
                 Query.parse_and_build(cv, :public, params)

        assert length(site_ids) == 2
        assert site.id in site_ids

        assert {:ok, %{consolidated_site_ids: site_ids}} =
                 Query.parse_and_build(cv, :internal, params)

        assert length(site_ids) == 2
        assert site.id in site_ids
      end
    end
  end
end
