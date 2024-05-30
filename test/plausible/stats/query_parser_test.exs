defmodule Plausible.Stats.Filters.QueryParserTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.Filters
  import Plausible.Stats.Filters.QueryParser

  def check_success(params, expected_result) do
    assert parse(params) == {:ok, expected_result}
  end

  def check_error(params, expected_error_message) do
    {:error, message} = parse(params)
    assert message =~ expected_error_message
  end

  test "parsing empty map fails" do
    %{}
    |> check_error("No valid metrics passed")
  end

  describe "metrics validation" do
    test "valid metrics passed" do
      %{"metrics" => ["visitors", "events"], "date_range" => "all"}
      |> check_success(%{
        metrics: [:visitors, :events],
        date_range: "all",
        filters: [],
        dimensions: [],
        order_by: nil
      })
    end

    test "invalid metric passed" do
      %{"metrics" => ["visitors", "event:name"], "date_range" => "all"}
      |> check_error("Unknown metric '\"event:name\"'")
    end

    test "fuller list of metrics" do
      %{
        "metrics" => [
          "time_on_page",
          "conversion_rate",
          "visitors",
          "pageviews",
          "visits",
          "events",
          "bounce_rate",
          "visit_duration"
        ],
        "date_range" => "all"
      }
      |> check_success(%{
        metrics: [
          :time_on_page,
          :conversion_rate,
          :visitors,
          :pageviews,
          :visits,
          :events,
          :bounce_rate,
          :visit_duration
        ],
        date_range: "all",
        filters: [],
        dimensions: [],
        order_by: nil
      })
    end

    test "same metric queried multiple times" do
      %{"metrics" => ["events", "visitors", "visitors"], "date_range" => "all"}
      |> check_error(~r/Metrics cannot be queried multiple times/)
    end
  end

  describe "filters validation" do
    for operation <- [:is, :is_not, :matches, :does_not_match] do
      test "#{operation} filter" do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", "foo"]
          ]
        }
        |> check_success(%{
          metrics: [:visitors],
          date_range: "all",
          filters: [
            [unquote(operation), "event:name", "foo"]
          ],
          dimensions: [],
          order_by: nil
        })
      end

      test "#{operation} filter with invalid clause" do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", ["foo"]]
          ]
        }
        |> check_error(~r/Invalid filter/)
      end
    end

    for operation <- [:member, :not_member, :matches_member, :not_matches_member] do
      test "#{operation} filter" do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", ["foo"]]
          ]
        }
        |> check_success(%{
          metrics: [:visitors],
          date_range: "all",
          filters: [
            [unquote(operation), "event:name", ["foo"]]
          ],
          dimensions: [],
          order_by: nil
        })
      end

      test "#{operation} filter with invalid clause" do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", "foo"]
          ]
        }
        |> check_error(~r/Invalid filter/)
      end
    end

    test "filtering by invalid operation" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["exists?", "event:name", ["foo"]]
        ]
      }
      |> check_error(~r/Unknown operator for filter/)
    end

    test "filtering by custom properties" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["member", "event:props:foobar", ["value"]]
        ]
      }
      |> check_success(%{
        metrics: [:visitors],
        date_range: "all",
        filters: [
          [:member, "event:props:foobar", ["value"]]
        ],
        dimensions: [],
        order_by: nil
      })
    end

    for dimension <- Filters.event_props() do
      test "filtering by event:#{dimension} filter" do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["member", "event:#{unquote(dimension)}", ["foo"]]
          ]
        }
        |> check_success(%{
          metrics: [:visitors],
          date_range: "all",
          filters: [
            [:member, "event:#{unquote(dimension)}", ["foo"]]
          ],
          dimensions: [],
          order_by: nil
        })
      end
    end

    for dimension <- Filters.visit_props() do
      test "filtering by visit:#{dimension} filter" do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["member", "visit:#{unquote(dimension)}", ["foo"]]
          ]
        }
        |> check_success(%{
          metrics: [:visitors],
          date_range: "all",
          filters: [
            [:member, "visit:#{unquote(dimension)}", ["foo"]]
          ],
          dimensions: [],
          order_by: nil
        })
      end
    end

    test "invalid event filter" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["member", "event:device", ["foo"]]
        ]
      }
      |> check_error(~r/Invalid filter /)
    end

    test "invalid visit filter" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["member", "visit:name", ["foo"]]
        ]
      }
      |> check_error(~r/Invalid filter /)
    end

    test "invalid filter" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => "foobar"
      }
      |> check_error(~r/Invalid filters passed/)
    end
  end

  describe "date range validation" do
  end

  describe "dimensions validation" do
    for dimension <- Filters.event_props() do
      test "event:#{dimension} dimension" do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:#{unquote(dimension)}"]
        }
        |> check_success(%{
          metrics: [:visitors],
          date_range: "all",
          filters: [],
          dimensions: ["event:#{unquote(dimension)}"],
          order_by: nil
        })
      end
    end

    for dimension <- Filters.visit_props() do
      test "visit:#{dimension} dimension" do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:#{unquote(dimension)}"]
        }
        |> check_success(%{
          metrics: [:visitors],
          date_range: "all",
          filters: [],
          dimensions: ["visit:#{unquote(dimension)}"],
          order_by: nil
        })
      end
    end

    test "custom properties dimension" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:foobar"]
      }
      |> check_success(%{
        metrics: [:visitors],
        date_range: "all",
        filters: [],
        dimensions: ["event:props:foobar"],
        order_by: nil
      })
    end

    test "invalid dimension name passed" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visitors"]
      }
      |> check_error(~r/Invalid dimensions/)
    end

    test "invalid dimension" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => "foobar"
      }
      |> check_error(~r/Invalid dimensions/)
    end

    test "dimensions are not unique" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name", "event:name"]
      }
      |> check_error(~r/Some dimensions are listed multiple times/)
    end
  end

  describe "order_by validation" do
    test "ordering by metric" do
      %{
        "metrics" => ["visitors", "events"],
        "date_range" => "all",
        "order_by" => [["events", "desc"], ["visitors", "asc"]]
      }
      |> check_success(%{
        metrics: [:visitors, :events],
        date_range: "all",
        filters: [],
        dimensions: [],
        order_by: [{:events, :desc}, {:visitors, :asc}]
      })
    end

    test "ordering by dimension" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name"],
        "order_by" => [["event:name", "desc"]]
      }
      |> check_success(%{
        metrics: [:visitors],
        date_range: "all",
        filters: [],
        dimensions: ["event:name"],
        order_by: [{"event:name", :desc}]
      })
    end

    test "ordering by invalid value" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["visssss", "desc"]]
      }
      |> check_error(~r/Invalid order_by entry/)
    end

    test "ordering by not queried metric" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["events", "desc"]]
      }
      |> check_error(~r/Entry is not a queried metric or dimension/)
    end

    test "ordering by not queried dimension" do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["event:name", "desc"]]
      }
      |> check_error(~r/Entry is not a queried metric or dimension/)
    end
  end
end
