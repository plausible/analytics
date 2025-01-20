defmodule Plausible.Stats.Filters.QueryParserTest do
  use Plausible
  use Plausible.DataCase
  use Plausible.Teams.Test
  import Plausible.Stats.Filters.QueryParser
  doctest Plausible.Stats.Filters.QueryParser

  alias Plausible.Stats.DateTimeRange
  alias Plausible.Stats.Filters

  setup [:create_user, :create_site]

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
    first: DateTime.new!(~D[2021-04-29], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-05], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_30d %DateTimeRange{
    first: DateTime.new!(~D[2021-04-05], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-05], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_month %DateTimeRange{
    first: DateTime.new!(~D[2021-05-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-31], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_6mo %DateTimeRange{
    first: DateTime.new!(~D[2020-12-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-31], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_year %DateTimeRange{
    first: DateTime.new!(~D[2021-01-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-12-31], ~T[23:59:59], "Etc/UTC")
  }
  @date_range_12mo %DateTimeRange{
    first: DateTime.new!(~D[2020-06-01], ~T[00:00:00], "Etc/UTC"),
    last: DateTime.new!(~D[2021-05-31], ~T[23:59:59], "Etc/UTC")
  }

  def check_success(params, site, expected_result, schema_type \\ :public) do
    assert {:ok, result} = parse(site, schema_type, params, @now)

    return_value = Map.take(result, [:preloaded_goals, :revenue_warning, :revenue_currencies])
    result = Map.drop(result, [:preloaded_goals, :revenue_warning, :revenue_currencies])
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
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      }

    check_success(params, site, expected_parsed, schema_type)
  end

  def check_goals(actual, opts) do
    preloaded_goal_names =
      actual[:preloaded_goals]
      |> Enum.map(& &1.display_name)
      |> Enum.sort()

    assert preloaded_goal_names == Keyword.get(opts, :preloaded_goals)
    assert actual[:revenue_warning] == Keyword.get(opts, :revenue_warning)
    assert actual[:revenue_currencies] == Keyword.get(opts, :revenue_currencies)
  end

  test "parsing empty map fails", %{site: site} do
    %{}
    |> check_error(site, "#: Required properties site_id, metrics, date_range were not present.")
  end

  describe "metrics validation" do
    test "valid metrics passed", %{site: site} do
      %{"site_id" => site.domain, "metrics" => ["visitors", "events"], "date_range" => "all"}
      |> check_success(site, %{
        metrics: [:visitors, :events],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "invalid metric passed", %{site: site} do
      %{"site_id" => site.domain, "metrics" => ["visitors", "event:name"], "date_range" => "all"}
      |> check_error(site, "#/metrics/1: Invalid metric \"event:name\"")
    end

    test "fuller list of metrics", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => [
          "time_on_page",
          "visitors",
          "pageviews",
          "visits",
          "events",
          "bounce_rate",
          "visit_duration"
        ],
        "date_range" => "all"
      }
      |> check_success(
        site,
        %{
          metrics: [
            :time_on_page,
            :visitors,
            :pageviews,
            :visits,
            :events,
            :bounce_rate,
            :visit_duration
          ],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        },
        :internal
      )
    end

    test "time_on_page is not a valid metric in public API", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["time_on_page"],
        "date_range" => "all"
      }
      |> check_error(site, "#/metrics/0: Invalid metric \"time_on_page\"")
    end

    test "same metric queried multiple times", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["events", "visitors", "visitors"],
        "date_range" => "all"
      }
      |> check_error(site, "#/metrics: Expected items to be unique but they were not.")
    end

    test "no metrics passed", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => [],
        "date_range" => "all"
      }
      |> check_error(site, "#/metrics: Expected a minimum of 1 items but got 0.")
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
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", ["foo"]]
          ]
        }
        |> check_success(
          site,
          %{
            metrics: [:visitors],
            utc_time_range: @date_range_day,
            filters: [
              [unquote(operation), "event:name", ["foo"]]
            ],
            dimensions: [],
            order_by: nil,
            timezone: site.timezone,
            include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
            pagination: %{limit: 10_000, offset: 0}
          },
          :internal
        )
      end

      test "#{operation} filter with invalid clause", %{site: site} do
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", "foo"]
          ]
        }
        |> check_error(
          site,
          "#/filters/0: Invalid filter [\"#{unquote(operation)}\", \"event:name\", \"foo\"]",
          :internal
        )
      end
    end

    for operation <- [:matches_wildcard, :matches_wildcard_not] do
      test "#{operation} is not a valid filter operation in public API", %{site: site} do
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", ["foo"]]
          ]
        }
        |> check_error(
          site,
          "#/filters/0: Invalid filter [\"#{unquote(operation)}\", \"event:name\", [\"foo\"]]"
        )
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
          ["is_not", "event:name"]
        ] do
      test "errors on too short filter #{inspect(too_short_filter)}", %{
        site: site
      } do
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            unquote(too_short_filter)
          ]
        }
        |> check_error(
          site,
          ~s(#/filters/0: Invalid filter #{inspect(unquote(too_short_filter))})
        )
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
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            unquote(too_long_filter)
          ]
        }
        |> check_error(
          site,
          ~s(#/filters/0: Invalid filter #{inspect(unquote(too_long_filter))})
        )
      end
    end

    test "filtering by invalid operation", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["exists?", "event:name", ["foo"]]
        ]
      }
      |> check_error(site, "#/filters/0: Invalid filter [\"exists?\", \"event:name\", [\"foo\"]]")
    end

    test "filtering by custom properties", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:props:foobar", ["value"]]
        ]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [
          [:is, "event:props:foobar", ["value"]]
        ],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    for dimension <- Filters.event_props() do
      if dimension != "goal" do
        test "filtering by event:#{dimension} filter", %{site: site} do
          %{
            "site_id" => site.domain,
            "metrics" => ["visitors"],
            "date_range" => "all",
            "filters" => [
              ["is", "event:#{unquote(dimension)}", ["foo"]]
            ]
          }
          |> check_success(site, %{
            metrics: [:visitors],
            utc_time_range: @date_range_day,
            filters: [
              [:is, "event:#{unquote(dimension)}", ["foo"]]
            ],
            dimensions: [],
            order_by: nil,
            timezone: site.timezone,
            include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
            pagination: %{limit: 10_000, offset: 0}
          })
        end
      end
    end

    for dimension <- Filters.visit_props() do
      test "filtering by visit:#{dimension} filter", %{site: site} do
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["is", "visit:#{unquote(dimension)}", ["ab"]]
          ]
        }
        |> check_success(site, %{
          metrics: [:visitors],
          utc_time_range: @date_range_day,
          filters: [
            [:is, "visit:#{unquote(dimension)}", ["ab"]]
          ],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        })
      end
    end

    test "invalid event filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:device", ["foo"]]
        ]
      }
      |> check_error(site, "#/filters/0: Invalid filter [\"is\", \"event:device\", [\"foo\"]]")
    end

    test "invalid visit filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "visit:name", ["foo"]]
        ]
      }
      |> check_error(site, "#/filters/0: Invalid filter [\"is\", \"visit:name\", [\"foo\"]]")
    end

    test "invalid filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => "foobar"
      }
      |> check_error(site, "#/filters: Type mismatch. Expected Array but got String.")
    end

    test "numeric filter is invalid", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "visit:os_version", [123]]]
      }
      |> check_error(site, "Invalid filter '[\"is\", \"visit:os_version\", [123]]'.")
    end

    test "numbers and strings are valid for visit:city", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "visit:city", [123, 456]]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [
          [:is, "visit:city", [123, 456]]
        ],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })

      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "visit:city", ["123", "456"]]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [
          [:is, "visit:city", ["123", "456"]]
        ],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "invalid visit:country filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "visit:country", ["USA"]]]
      }
      |> check_error(
        site,
        "Invalid visit:country filter, visit:country needs to be a valid 2-letter country code."
      )
    end

    test "valid nested `not`, `and` and `or`", %{site: site} do
      %{
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
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
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
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "invalid `not` clause", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["not", []]]
      }
      |> check_error(
        site,
        "#/filters/0: Invalid filter [\"not\", []]"
      )
    end

    test "invalid `or` clause", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["or", []]]
      }
      |> check_error(
        site,
        "#/filters/0: Invalid filter [\"or\", []]"
      )
    end

    test "event:hostname filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "event:hostname", ["a.plausible.io"]]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [
          [:is, "event:hostname", ["a.plausible.io"]]
        ],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "event:hostname filter not at top level is invalid", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["not", ["is", "event:hostname", ["a.plausible.io"]]]]
      }
      |> check_error(
        site,
        "Invalid filters. Dimension `event:hostname` can only be filtered at the top level."
      )
    end

    for operation <- [:is, :contains, :is_not, :contains_not] do
      test "#{operation} allows case_sensitive modifier", %{site: site} do
        %{
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
        |> check_success(site, %{
          metrics: [:visitors],
          utc_time_range: @date_range_day,
          filters: [
            [unquote(operation), "event:page", ["/foo"], %{case_sensitive: false}],
            [unquote(operation), "event:name", ["/foo"], %{case_sensitive: true}]
          ],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        })
      end
    end

    for operation <- [:matches, :matches_not, :matches_wildcard, :matches_wildcard_not] do
      test "case_sensitive modifier is not valid for #{operation}", %{site: site} do
        %{
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
        |> check_error(
          site,
          "#/filters/0: Invalid filter [\"#{unquote(operation)}\", \"event:hostname\", [\"a.plausible.io\"], %{\"case_sensitive\" => false}]",
          :internal
        )
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
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup", "Purchase"]]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [[:is, "event:goal", ["Signup", "Purchase"]]],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
      |> check_goals(preloaded_goals: ["Purchase", "Signup"], revenue_currencies: %{})
    end

    test "with case insensitive match", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["signup", "purchase"], %{"case_sensitive" => false}]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [[:is, "event:goal", ["signup", "purchase"], %{case_sensitive: false}]],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
      |> check_goals(preloaded_goals: ["Purchase", "Signup"], revenue_currencies: %{})
    end

    test "with contains match", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["contains", "event:goal", ["Sign", "pur"]]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [[:contains, "event:goal", ["Sign", "pur"]]],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
      |> check_goals(preloaded_goals: ["Signup"], revenue_currencies: %{})
    end

    test "with case insensitive contains match", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["contains", "event:goal", ["sign", "CONT"], %{"case_sensitive" => false}]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [[:contains, "event:goal", ["sign", "CONT"], %{case_sensitive: false}]],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
      |> check_goals(preloaded_goals: ["Contact", "Signup"], revenue_currencies: %{})
    end
  end

  describe "include validation" do
    test "setting include values", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["time"],
        "include" => %{"imports" => true, "time_labels" => true, "total_rows" => true}
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: ["time"],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: true, time_labels: true, total_rows: true, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "setting invalid imports value", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => "foobar"
      }
      |> check_error(site, "#/include: Type mismatch. Expected Object but got String.")
    end

    test "setting include.time_labels without time dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"time_labels" => true}
      }
      |> check_error(site, "Invalid include.time_labels: requires a time dimension.")
    end
  end

  describe "include.comparisons" do
    test "not allowed in public API", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"comparisons" => %{"mode" => "previous_period"}}
      }
      |> check_error(
        site,
        "#/include/comparisons: Schema does not allow additional properties."
      )
    end

    test "mode=previous_period", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"comparisons" => %{"mode" => "previous_period"}}
      }
      |> check_success(
        site,
        %{
          metrics: [:visitors],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{
            comparisons: %{
              mode: "previous_period"
            },
            imports: false,
            time_labels: false,
            total_rows: false
          },
          pagination: %{limit: 10_000, offset: 0}
        },
        :internal
      )
    end

    test "mode=year_over_year", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"comparisons" => %{"mode" => "year_over_year"}}
      }
      |> check_success(
        site,
        %{
          metrics: [:visitors],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{
            comparisons: %{
              mode: "year_over_year"
            },
            imports: false,
            time_labels: false,
            total_rows: false
          },
          pagination: %{limit: 10_000, offset: 0}
        },
        :internal
      )
    end

    test "mode=custom", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{
          "comparisons" => %{"mode" => "custom", "date_range" => ["2021-04-05", "2021-05-05"]}
        }
      }
      |> check_success(
        site,
        %{
          metrics: [:visitors],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{
            comparisons: %{
              mode: "custom",
              date_range: @date_range_30d
            },
            imports: false,
            time_labels: false,
            total_rows: false
          },
          pagination: %{limit: 10_000, offset: 0}
        },
        :internal
      )
    end

    test "mode=custom without date_range is invalid", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "include" => %{"comparisons" => %{"mode" => "custom"}}
      }
      |> check_error(
        site,
        "#/include/comparisons: Expected exactly one of the schemata to match, but none of them did.",
        :internal
      )
    end

    test "mode=previous_period with date_range is invalid", %{site: site} do
      %{
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
      |> check_error(
        site,
        "#/include/comparisons: Expected exactly one of the schemata to match, but none of them did.",
        :internal
      )
    end
  end

  describe "pagination validation" do
    test "setting pagination values", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["time"],
        "pagination" => %{"limit" => 100, "offset" => 200}
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: ["time"],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 100, offset: 200}
      })
    end

    test "out of range limit value", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "pagination" => %{"limit" => 100_000}
      }
      |> check_error(site, "#/pagination/limit: Expected the value to be <= 10000")
    end

    test "out of range offset value", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "pagination" => %{"offset" => -5}
      }
      |> check_error(site, "#/pagination/offset: Expected the value to be >= 0")
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

      assert {:ok, res} = parse(site, :public, params, @now)
      expected_timezone = site.timezone

      assert %{
               metrics: [:visitors],
               utc_time_range: @date_range_day,
               filters: [
                 [:is, "event:goal", ["Signup", "Visit /thank-you"]]
               ],
               dimensions: [],
               order_by: nil,
               timezone: ^expected_timezone,
               include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
               pagination: %{limit: 10_000, offset: 0},
               preloaded_goals: [
                 %Plausible.Goal{page_path: "/thank-you"},
                 %Plausible.Goal{event_name: "Signup"}
               ]
             } = res
    end

    test "invalid event filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:goal", ["Signup"]]
        ]
      }
      |> check_error(
        site,
        "The goal `Signup` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
      )
    end

    test "invalid page filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:goal", ["Visit /thank-you"]]
        ]
      }
      |> check_error(
        site,
        "The goal `Visit /thank-you` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
      )
    end

    test "unsupported filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is_not", "event:goal", ["Signup"]]
        ]
      }
      |> check_error(
        site,
        "#/filters/0: Invalid filter [\"is_not\", \"event:goal\", [\"Signup\"]]"
      )
    end

    test "not top-level filter", %{site: site} do
      %{
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
      |> check_error(
        site,
        "Invalid filters. Dimension `event:goal` can only be filtered at the top level."
      )
    end
  end

  describe "date range validation" do
    test "parsing shortcut options", %{site: site} do
      check_date_range(%{"date_range" => "day"}, site, @date_range_day)
      check_date_range(%{"date_range" => "7d"}, site, @date_range_7d)
      check_date_range(%{"date_range" => "30d"}, site, @date_range_30d)
      check_date_range(%{"date_range" => "month"}, site, @date_range_month)
      check_date_range(%{"date_range" => "6mo"}, site, @date_range_6mo)
      check_date_range(%{"date_range" => "12mo"}, site, @date_range_12mo)
      check_date_range(%{"date_range" => "year"}, site, @date_range_year)
    end

    test "30m and realtime are available in internal API", %{site: site} do
      check_date_range(%{"date_range" => "30m"}, site, @date_range_30m, :internal)

      check_date_range(
        %{"date_range" => "realtime"},
        site,
        @date_range_realtime,
        :internal
      )
    end

    test "30m and realtime date_ranges are unavailable in public API", %{
      site: site
    } do
      for date_range <- ["realtime", "30m"] do
        %{"site_id" => site.domain, "metrics" => ["visitors"], "date_range" => date_range}
        |> check_error(site, "#/date_range: Invalid date range \"#{date_range}\"")
      end
    end

    test "parsing `all` with previous data", %{site: site} do
      site = Map.put(site, :stats_start_date, ~D[2020-01-01])
      expected_date_range = DateTimeRange.new!(~D[2020-01-01], ~D[2021-05-05], "Etc/UTC")
      check_date_range(%{"date_range" => "all"}, site, expected_date_range)
    end

    test "parsing `all` with no previous data", %{site: site} do
      site = Map.put(site, :stats_start_date, nil)
      check_date_range(%{"date_range" => "all"}, site, @date_range_day)
    end

    test "parsing custom date range from simple date strings", %{site: site} do
      check_date_range(%{"date_range" => ["2021-05-05", "2021-05-05"]}, site, @date_range_day)
    end

    test "parsing custom date range from iso8601 timestamps", %{site: site} do
      check_date_range(
        %{"date_range" => ["2024-01-01T00:00:00Z", "2024-01-02T23:59:59Z"]},
        site,
        DateTimeRange.new!(
          DateTime.new!(~D[2024-01-01], ~T[00:00:00], "Etc/UTC"),
          DateTime.new!(~D[2024-01-02], ~T[23:59:59], "Etc/UTC")
        )
      )

      check_date_range(
        %{
          "date_range" => [
            "2024-08-29T07:12:34-07:00",
            "2024-08-29T10:12:34-07:00"
          ]
        },
        site,
        DateTimeRange.new!(
          ~U[2024-08-29 14:12:34Z],
          ~U[2024-08-29 17:12:34Z]
        )
      )
    end

    test "parsing invalid custom date range with invalid dates", %{site: site} do
      %{"site_id" => site.domain, "date_range" => "foo", "metrics" => ["visitors"]}
      |> check_error(site, "#/date_range: Invalid date range \"foo\"")

      %{"site_id" => site.domain, "date_range" => ["21415-00", "eee"], "metrics" => ["visitors"]}
      |> check_error(site, "#/date_range: Invalid date range [\"21415-00\", \"eee\"]")
    end

    test "custom date range is invalid when timestamps do not include timezone info", %{
      site: site
    } do
      %{
        "site_id" => site.domain,
        "date_range" => ["2021-02-03T00:00:00", "2021-02-03T23:59:59"],
        "metrics" => ["visitors"]
      }
      |> check_error(
        site,
        "Invalid date_range '[\"2021-02-03T00:00:00\", \"2021-02-03T23:59:59\"]'."
      )
    end

    test "custom date range is invalid when timestamp timezone is invalid", %{site: site} do
      %{
        "site_id" => site.domain,
        "date_range" => ["2021-02-03T00:00:00-25:00", "2021-02-03T23:59:59-25:00"],
        "metrics" => ["visitors"]
      }
      |> check_error(
        site,
        "#/date_range: Invalid date range [\"2021-02-03T00:00:00-25:00\", \"2021-02-03T23:59:59-25:00\"]"
      )
    end

    test "custom date range is invalid when date and timestamp are combined", %{site: site} do
      %{
        "site_id" => site.domain,
        "date_range" => ["2021-02-03T00:00:00Z", "2021-02-04"],
        "metrics" => ["visitors"]
      }
      |> check_error(
        site,
        "#/date_range: Invalid date range [\"2021-02-03T00:00:00Z\", \"2021-02-04\"]"
      )
    end

    test "parses date_range relative to date param", %{site: site} do
      date = @now |> DateTime.to_date() |> Date.to_string()

      for {date_range_shortcut, expected_date_range} <- [
            {"day", @date_range_day},
            {"7d", @date_range_7d},
            {"30d", @date_range_30d},
            {"month", @date_range_month},
            {"6mo", @date_range_6mo},
            {"12mo", @date_range_12mo},
            {"year", @date_range_year}
          ] do
        %{"date_range" => date_range_shortcut, "date" => date}
        |> check_date_range(site, expected_date_range, :internal)
      end
    end

    test "date parameter is not available in the public API", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "month",
        "date" => "2021-05-05"
      }
      |> check_error(site, "#/date: Schema does not allow additional properties.")
    end

    test "parses date_range.first into a datetime right after the gap in site.timezone", %{
      site: site
    } do
      site = %{site | timezone: "America/Santiago"}

      %{"date_range" => ["2022-09-11", "2022-09-11"]}
      |> check_date_range(
        site,
        DateTimeRange.new!(~U[2022-09-11 04:00:00Z], ~U[2022-09-12 02:59:59Z])
      )
    end

    test "parses date_range.first into the latest of ambiguous datetimes in site.timezone", %{
      site: site
    } do
      site = %{site | timezone: "America/Havana"}

      %{"date_range" => ["2023-11-05", "2023-11-05"]}
      |> check_date_range(
        site,
        DateTimeRange.new!(~U[2023-11-05 05:00:00Z], ~U[2023-11-06 04:59:59Z])
      )
    end

    test "parses date_range.last into the earliest of ambiguous datetimes in site.timezone", %{
      site: site
    } do
      site = %{site | timezone: "America/Asuncion"}

      %{"date_range" => ["2024-03-23", "2024-03-23"]}
      |> check_date_range(
        site,
        DateTimeRange.new!(~U[2024-03-23 03:00:00Z], ~U[2024-03-24 02:59:59Z])
      )
    end
  end

  describe "dimensions validation" do
    for dimension <- Filters.event_props() do
      test "event:#{dimension} dimension", %{site: site} do
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:#{unquote(dimension)}"]
        }
        |> check_success(site, %{
          metrics: [:visitors],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: ["event:#{unquote(dimension)}"],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        })
      end
    end

    for dimension <- Filters.visit_props() do
      test "visit:#{dimension} dimension", %{site: site} do
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:#{unquote(dimension)}"]
        }
        |> check_success(site, %{
          metrics: [:visitors],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: ["visit:#{unquote(dimension)}"],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        })
      end
    end

    test "custom properties dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:foobar"]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: ["event:props:foobar"],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "invalid custom property dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:"]
      }
      |> check_error(site, "#/dimensions/0: Invalid dimension \"event:props:\"")
    end

    test "invalid dimension name passed", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visitors"]
      }
      |> check_error(site, "#/dimensions/0: Invalid dimension \"visitors\"")
    end

    test "invalid dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => "foobar"
      }
      |> check_error(site, "#/dimensions: Type mismatch. Expected Array but got String.")
    end

    test "dimensions are not unique", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name", "event:name"]
      }
      |> check_error(site, "#/dimensions: Expected items to be unique but they were not.")
    end
  end

  describe "order_by validation" do
    test "ordering by metric", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events"],
        "date_range" => "all",
        "order_by" => [["events", "desc"], ["visitors", "asc"]]
      }
      |> check_success(site, %{
        metrics: [:visitors, :events],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: [],
        order_by: [{:events, :desc}, {:visitors, :asc}],
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "ordering by dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name"],
        "order_by" => [["event:name", "desc"]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: ["event:name"],
        order_by: [{"event:name", :desc}],
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "ordering by invalid value", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["visssss", "desc"]]
      }
      |> check_error(site, "#/order_by/0/0: Invalid value in order_by \"visssss\"")
    end

    test "ordering by not queried metric", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["events", "desc"]]
      }
      |> check_error(
        site,
        "Invalid order_by entry '{:events, :desc}'. Entry is not a queried metric or dimension."
      )
    end

    test "ordering by not queried dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["event:name", "desc"]]
      }
      |> check_error(
        site,
        "Invalid order_by entry '{\"event:name\", :desc}'. Entry is not a queried metric or dimension."
      )
    end
  end

  describe "custom props access" do
    test "filters - no access", %{site: site, user: user} do
      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.StatsAPI])

      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["not", ["is", "event:props:foobar", ["foo"]]]]
      }
      |> check_error(
        site,
        "The owner of this site does not have access to the custom properties feature."
      )
    end

    test "dimensions - no access", %{site: site, user: user} do
      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.StatsAPI])

      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:foobar"]
      }
      |> check_error(
        site,
        "The owner of this site does not have access to the custom properties feature."
      )
    end
  end

  describe "conversion_rate metric" do
    test "fails validation on its own", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all"
      }
      |> check_error(
        site,
        "Metric `conversion_rate` can only be queried with event:goal filters or dimensions."
      )
    end

    test "succeeds with event:goal filter", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, event_name: "Purchase", currency: "USD"})

      %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }
      |> check_success(site, %{
        metrics: [:conversion_rate],
        utc_time_range: @date_range_day,
        filters: [[:is, "event:goal", ["Signup"]]],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
      |> check_goals(preloaded_goals: ["Signup"], revenue_currencies: %{})
    end

    test "succeeds with event:goal dimension", %{site: site} do
      insert(:goal, %{site: site, event_name: "Purchase", currency: "USD"})
      insert(:goal, %{site: site, event_name: "Signup"})

      %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["event:goal"]
      }
      |> check_success(site, %{
        metrics: [:conversion_rate],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: ["event:goal"],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
      |> check_goals(preloaded_goals: ["Purchase", "Signup"], revenue_currencies: %{})
    end

    test "custom properties filter with special metric", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate", "group_conversion_rate"],
        "date_range" => "all",
        "filters" => [["is", "event:props:foo", ["bar"]]],
        "dimensions" => ["event:goal"]
      }
      |> check_success(site, %{
        metrics: [:conversion_rate, :group_conversion_rate],
        utc_time_range: @date_range_day,
        filters: [
          [:is, "event:props:foo", ["bar"]]
        ],
        dimensions: ["event:goal"],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "not top level custom properties filter with special metric is invalid", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate", "group_conversion_rate"],
        "date_range" => "all",
        "filters" => [["not", ["is", "event:props:foo", ["bar"]]]],
        "dimensions" => ["event:goal"]
      }
      |> check_error(
        site,
        "Invalid filters. When `conversion_rate` or `group_conversion_rate` metrics are used, custom property filters can only be used on top level."
      )
    end
  end

  describe "scroll_depth metric" do
    test "fails validation on its own", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["scroll_depth"],
        "date_range" => "all"
      }
      |> check_error(
        site,
        "Metric `scroll_depth` can only be queried with event:page filters or dimensions.",
        :internal
      )
    end

    test "fails with only a non-top-level event:page filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["scroll_depth"],
        "date_range" => "all",
        "filters" => [["not", ["is", "event:page", ["/"]]]]
      }
      |> check_error(
        site,
        "Metric `scroll_depth` can only be queried with event:page filters or dimensions.",
        :internal
      )
    end

    test "succeeds with top-level event:page filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["scroll_depth"],
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]]
      }
      |> check_success(
        site,
        %{
          metrics: [:scroll_depth],
          utc_time_range: @date_range_day,
          filters: [[:is, "event:page", ["/"]]],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        },
        :internal
      )
    end

    test "succeeds with event:page dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["scroll_depth"],
        "date_range" => "all",
        "dimensions" => ["event:page"]
      }
      |> check_success(
        site,
        %{
          metrics: [:scroll_depth],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: ["event:page"],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        },
        :internal
      )
    end
  end

  describe "views_per_visit metric" do
    test "succeeds with normal filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      %{
        "site_id" => site.domain,
        "metrics" => ["views_per_visit"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }
      |> check_success(site, %{
        metrics: [:views_per_visit],
        utc_time_range: @date_range_day,
        filters: [[:is, "event:goal", ["Signup"]]],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
      |> check_goals(preloaded_goals: ["Signup"], revenue_currencies: %{})
    end

    test "fails validation if event:page filter specified", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["views_per_visit"],
        "date_range" => "all",
        "filters" => [["is", "event:page", ["/"]]]
      }
      |> check_error(
        site,
        "Metric `views_per_visit` cannot be queried with a filter on `event:page`."
      )
    end

    test "fails validation with dimensions", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["views_per_visit"],
        "date_range" => "all",
        "dimensions" => ["event:name"]
      }
      |> check_error(
        site,
        "Metric `views_per_visit` cannot be queried with `dimensions`."
      )
    end
  end

  describe "revenue metrics" do
    @describetag :ee_only

    setup %{user: user} do
      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.RevenueGoals])
      :ok
    end

    test "can request", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all"
      }
      |> check_success(
        site,
        %{
          metrics: [:total_revenue, :average_revenue],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        }
      )
      |> check_goals(
        preloaded_goals: [],
        revenue_warning: :no_revenue_goals_matching,
        revenue_currencies: %{}
      )
    end

    test "no access" do
      user = new_user()
      site = new_site(owner: user)

      subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.StatsAPI])

      %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all"
      }
      |> check_error(
        site,
        "The owner of this site does not have access to the revenue metrics feature."
      )
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

      %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["PurchaseUSD", "Signup", "Subscription"]]]
      }
      |> check_success(
        site,
        %{
          metrics: [:total_revenue, :average_revenue],
          utc_time_range: @date_range_day,
          filters: [[:is, "event:goal", ["PurchaseUSD", "Signup", "Subscription"]]],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        }
      )
      |> check_goals(
        preloaded_goals: ["PurchaseUSD", "Signup", "Subscription"],
        revenue_warning: nil,
        revenue_currencies: %{default: :USD}
      )
    end

    test "with event:goal filters with different currencies", %{site: site} do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Subscription", currency: "EUR")
      insert(:goal, site: site, event_name: "Signup")

      %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Purchase", "Signup", "Subscription"]]]
      }
      |> check_success(
        site,
        %{
          metrics: [:total_revenue, :average_revenue],
          utc_time_range: @date_range_day,
          filters: [[:is, "event:goal", ["Purchase", "Signup", "Subscription"]]],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        }
      )
      |> check_goals(
        preloaded_goals: ["Purchase", "Signup", "Subscription"],
        revenue_warning: :no_single_revenue_currency,
        revenue_currencies: %{}
      )
    end

    test "with event:goal filters with no revenue currencies", %{site: site} do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Subscription", currency: "EUR")
      insert(:goal, site: site, event_name: "Signup")

      %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }
      |> check_success(
        site,
        %{
          metrics: [:total_revenue, :average_revenue],
          utc_time_range: @date_range_day,
          filters: [[:is, "event:goal", ["Signup"]]],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        }
      )
      |> check_goals(
        preloaded_goals: ["Signup"],
        revenue_warning: :no_revenue_goals_matching,
        revenue_currencies: %{}
      )
    end

    test "with event:goal dimension, different currencies", %{site: site} do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Donation", currency: "EUR")
      insert(:goal, site: site, event_name: "Signup")

      %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "dimensions" => ["event:goal"]
      }
      |> check_success(
        site,
        %{
          metrics: [:total_revenue, :average_revenue],
          utc_time_range: @date_range_day,
          filters: [],
          dimensions: ["event:goal"],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        }
      )
      |> check_goals(
        preloaded_goals: ["Donation", "Purchase", "Signup"],
        revenue_warning: nil,
        revenue_currencies: %{"Donation" => :EUR, "Purchase" => :USD}
      )
    end

    test "with event:goal dimension and filters", %{site: site} do
      insert(:goal, site: site, event_name: "Purchase", currency: "USD")
      insert(:goal, site: site, event_name: "Subscription", currency: "EUR")
      insert(:goal, site: site, event_name: "Signup")
      insert(:goal, site: site, event_name: "Logout")

      %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "dimensions" => ["event:goal"],
        "filters" => [["is", "event:goal", ["Purchase", "Signup", "Subscription"]]]
      }
      |> check_success(
        site,
        %{
          metrics: [:total_revenue, :average_revenue],
          utc_time_range: @date_range_day,
          filters: [[:is, "event:goal", ["Purchase", "Signup", "Subscription"]]],
          dimensions: ["event:goal"],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        }
      )
      |> check_goals(
        preloaded_goals: ["Purchase", "Signup", "Subscription"],
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

      %{
        "site_id" => site.domain,
        "metrics" => ["total_revenue", "average_revenue"],
        "date_range" => "all",
        "dimensions" => ["event:goal"],
        "filters" => [["is", "event:goal", ["Signup"]]]
      }
      |> check_success(
        site,
        %{
          metrics: [:total_revenue, :average_revenue],
          utc_time_range: @date_range_day,
          filters: [[:is, "event:goal", ["Signup"]]],
          dimensions: ["event:goal"],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        }
      )
      |> check_goals(
        preloaded_goals: ["Signup"],
        revenue_warning: :no_revenue_goals_matching,
        revenue_currencies: %{}
      )
    end
  end

  @tag :ce_build_only
  test "revenue metrics are not available on CE", %{site: site} do
    %{
      "site_id" => site.domain,
      "metrics" => ["total_revenue", "average_revenue"],
      "date_range" => "all"
    }
    |> check_error(
      site,
      "#/metrics/0: Invalid metric \"total_revenue\"\n#/metrics/1: Invalid metric \"average_revenue\""
    )
  end

  describe "session metrics" do
    test "single session metric succeeds", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "dimensions" => ["visit:device"]
      }
      |> check_success(site, %{
        metrics: [:bounce_rate],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: ["visit:device"],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "fails if using session metric with event dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "dimensions" => ["event:props:foo"]
      }
      |> check_error(
        site,
        "Session metric(s) `bounce_rate` cannot be queried along with event dimensions."
      )
    end

    test "does not fail if using session metric with event:page dimension", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "dimensions" => ["event:page"]
      }
      |> check_success(site, %{
        metrics: [:bounce_rate],
        utc_time_range: @date_range_day,
        filters: [],
        dimensions: ["event:page"],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
    end

    test "does not fail if using session metric with event filter", %{site: site} do
      %{
        "site_id" => site.domain,
        "metrics" => ["bounce_rate"],
        "date_range" => "all",
        "filters" => [["is", "event:props:foo", ["(none)"]]]
      }
      |> check_success(site, %{
        metrics: [:bounce_rate],
        utc_time_range: @date_range_day,
        filters: [[:is, "event:props:foo", ["(none)"]]],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone,
        include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
        pagination: %{limit: 10_000, offset: 0}
      })
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

      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["and", segments |> Enum.map(fn segment -> ["is", "segment", [segment.id]] end)]
        ]
      }
      |> check_error(
        site,
        "Invalid filters. You can only use up to 10 segment filters in a query.",
        :internal
      )
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

      %{
        "site_id" => site.domain,
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "segment", [segment.id]]]
      }
      |> check_error(
        site,
        "Invalid filters. Some segments don't exist or aren't accessible.",
        :internal
      )
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

      %{
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
      |> check_success(
        site,
        %{
          metrics: [:visitors, :events],
          utc_time_range: @date_range_day,
          filters: [
            [
              :and,
              [
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
              ]
            ]
          ],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone,
          include: %{imports: false, time_labels: false, total_rows: false, comparisons: nil},
          pagination: %{limit: 10_000, offset: 0}
        },
        :internal
      )
    end
  end
end
