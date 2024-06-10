defmodule Plausible.Stats.Filters.QueryParserTest do
  use Plausible.DataCase

  alias Plausible.Stats.Filters
  import Plausible.Stats.Filters.QueryParser

  setup [:create_user, :create_new_site]

  @date_range Date.range(Timex.today(), Timex.today())

  def check_success(params, site, expected_result) do
    assert parse(site, params) == {:ok, expected_result}
  end

  def check_error(params, site, expected_error_message) do
    {:error, message} = parse(site, params)
    assert message =~ expected_error_message
  end

  test "parsing empty map fails", %{site: site} do
    %{}
    |> check_error(site, "No valid metrics passed")
  end

  describe "metrics validation" do
    test "valid metrics passed", %{site: site} do
      %{"metrics" => ["visitors", "events"], "date_range" => "all"}
      |> check_success(site, %{
        metrics: [:visitors, :events],
        date_range: @date_range,
        filters: [],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone
      })
    end

    test "invalid metric passed", %{site: site} do
      %{"metrics" => ["visitors", "event:name"], "date_range" => "all"}
      |> check_error(site, "Unknown metric '\"event:name\"'")
    end

    test "fuller list of metrics", %{site: site} do
      %{
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
      |> check_success(site, %{
        metrics: [
          :time_on_page,
          :visitors,
          :pageviews,
          :visits,
          :events,
          :bounce_rate,
          :visit_duration
        ],
        date_range: @date_range,
        filters: [],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone
      })
    end

    test "same metric queried multiple times", %{site: site} do
      %{"metrics" => ["events", "visitors", "visitors"], "date_range" => "all"}
      |> check_error(site, ~r/Metrics cannot be queried multiple times/)
    end
  end

  describe "filters validation" do
    for operation <- [:is, :is_not, :matches, :does_not_match] do
      test "#{operation} filter", %{site: site} do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", ["foo"]]
          ]
        }
        |> check_success(site, %{
          metrics: [:visitors],
          date_range: @date_range,
          filters: [
            [unquote(operation), "event:name", ["foo"]]
          ],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone
        })
      end

      test "#{operation} filter with invalid clause", %{site: site} do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            [Atom.to_string(unquote(operation)), "event:name", "foo"]
          ]
        }
        |> check_error(site, ~r/Invalid filter/)
      end
    end

    test "filtering by invalid operation", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["exists?", "event:name", ["foo"]]
        ]
      }
      |> check_error(site, ~r/Unknown operator for filter/)
    end

    test "filtering by custom properties", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:props:foobar", ["value"]]
        ]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        date_range: @date_range,
        filters: [
          [:is, "event:props:foobar", ["value"]]
        ],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone
      })
    end

    for dimension <- Filters.event_props() do
      if dimension != "goal" do
        test "filtering by event:#{dimension} filter", %{site: site} do
          %{
            "metrics" => ["visitors"],
            "date_range" => "all",
            "filters" => [
              ["is", "event:#{unquote(dimension)}", ["foo"]]
            ]
          }
          |> check_success(site, %{
            metrics: [:visitors],
            date_range: @date_range,
            filters: [
              [:is, "event:#{unquote(dimension)}", ["foo"]]
            ],
            dimensions: [],
            order_by: nil,
            timezone: site.timezone
          })
        end
      end
    end

    for dimension <- Filters.visit_props() do
      test "filtering by visit:#{dimension} filter", %{site: site} do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "filters" => [
            ["is", "visit:#{unquote(dimension)}", ["foo"]]
          ]
        }
        |> check_success(site, %{
          metrics: [:visitors],
          date_range: @date_range,
          filters: [
            [:is, "visit:#{unquote(dimension)}", ["foo"]]
          ],
          dimensions: [],
          order_by: nil,
          timezone: site.timezone
        })
      end
    end

    test "invalid event filter", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:device", ["foo"]]
        ]
      }
      |> check_error(site, ~r/Invalid filter /)
    end

    test "invalid visit filter", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "visit:name", ["foo"]]
        ]
      }
      |> check_error(site, ~r/Invalid filter /)
    end

    test "invalid filter", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => "foobar"
      }
      |> check_error(site, ~r/Invalid filters passed/)
    end
  end

  describe "event:goal filter validation" do
    test "valid filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})
      insert(:goal, %{site: site, page_path: "/thank-you"})

      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:goal", ["Signup", "Visit /thank-you"]]
        ]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        date_range: @date_range,
        filters: [
          [:is, "event:goal", [{:event, "Signup"}, {:page, "/thank-you"}]]
        ],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone
      })
    end

    test "invalid event filter", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:goal", ["Signup"]]
        ]
      }
      |> check_error(site, ~r/The goal `Signup` is not configured for this site/)
    end

    test "invalid page filter", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [
          ["is", "event:goal", ["Visit /thank-you"]]
        ]
      }
      |> check_error(site, ~r/The goal `Visit \/thank-you` is not configured for this site/)
    end
  end

  describe "date range validation" do
  end

  describe "dimensions validation" do
    for dimension <- Filters.event_props() do
      test "event:#{dimension} dimension", %{site: site} do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["event:#{unquote(dimension)}"]
        }
        |> check_success(site, %{
          metrics: [:visitors],
          date_range: @date_range,
          filters: [],
          dimensions: ["event:#{unquote(dimension)}"],
          order_by: nil,
          timezone: site.timezone
        })
      end
    end

    for dimension <- Filters.visit_props() do
      test "visit:#{dimension} dimension", %{site: site} do
        %{
          "metrics" => ["visitors"],
          "date_range" => "all",
          "dimensions" => ["visit:#{unquote(dimension)}"]
        }
        |> check_success(site, %{
          metrics: [:visitors],
          date_range: @date_range,
          filters: [],
          dimensions: ["visit:#{unquote(dimension)}"],
          order_by: nil,
          timezone: site.timezone
        })
      end
    end

    test "custom properties dimension", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:foobar"]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        date_range: @date_range,
        filters: [],
        dimensions: ["event:props:foobar"],
        order_by: nil,
        timezone: site.timezone
      })
    end

    test "invalid dimension name passed", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["visitors"]
      }
      |> check_error(site, ~r/Invalid dimensions/)
    end

    test "invalid dimension", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => "foobar"
      }
      |> check_error(site, ~r/Invalid dimensions/)
    end

    test "dimensions are not unique", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name", "event:name"]
      }
      |> check_error(site, ~r/Some dimensions are listed multiple times/)
    end
  end

  describe "order_by validation" do
    test "ordering by metric", %{site: site} do
      %{
        "metrics" => ["visitors", "events"],
        "date_range" => "all",
        "order_by" => [["events", "desc"], ["visitors", "asc"]]
      }
      |> check_success(site, %{
        metrics: [:visitors, :events],
        date_range: @date_range,
        filters: [],
        dimensions: [],
        order_by: [{:events, :desc}, {:visitors, :asc}],
        timezone: site.timezone
      })
    end

    test "ordering by dimension", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:name"],
        "order_by" => [["event:name", "desc"]]
      }
      |> check_success(site, %{
        metrics: [:visitors],
        date_range: @date_range,
        filters: [],
        dimensions: ["event:name"],
        order_by: [{"event:name", :desc}],
        timezone: site.timezone
      })
    end

    test "ordering by invalid value", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["visssss", "desc"]]
      }
      |> check_error(site, ~r/Invalid order_by entry/)
    end

    test "ordering by not queried metric", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["events", "desc"]]
      }
      |> check_error(site, ~r/Entry is not a queried metric or dimension/)
    end

    test "ordering by not queried dimension", %{site: site} do
      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "order_by" => [["event:name", "desc"]]
      }
      |> check_error(site, ~r/Entry is not a queried metric or dimension/)
    end
  end

  describe "custom props access" do
    test "error if invalid filter", %{site: site, user: user} do
      ep =
        insert(:enterprise_plan, features: [Plausible.Billing.Feature.StatsAPI], user_id: user.id)

      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "filters" => [["is", "event:props:foobar", ["foo"]]]
      }
      |> check_error(
        site,
        ~r/The owner of this site does not have access to the custom properties feature/
      )
    end

    test "error if invalid dimension", %{site: site, user: user} do
      ep =
        insert(:enterprise_plan, features: [Plausible.Billing.Feature.StatsAPI], user_id: user.id)

      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

      %{
        "metrics" => ["visitors"],
        "date_range" => "all",
        "dimensions" => ["event:props:foobar"]
      }
      |> check_error(
        site,
        ~r/The owner of this site does not have access to the custom properties feature/
      )
    end
  end

  describe "conversion_rate metric" do
    test "fails validation on its own", %{site: site} do
      %{
        "metrics" => ["conversion_rate"],
        "date_range" => "all"
      }
      |> check_error(
        site,
        ~r/Metric `conversion_rate` can only be queried with event:goal filters or dimensions/
      )
    end

    test "succeeds with event:goal filter", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      %{
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]]
      }
      |> check_success(site, %{
        metrics: [:conversion_rate],
        date_range: @date_range,
        filters: [[:is, "event:goal", [event: "Signup"]]],
        dimensions: [],
        order_by: nil,
        timezone: site.timezone
      })
    end

    test "succeeds with event:goal dimension", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      %{
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["event:goal"]
      }
      |> check_success(site, %{
        metrics: [:conversion_rate],
        date_range: @date_range,
        filters: [],
        dimensions: ["event:goal"],
        order_by: nil,
        timezone: site.timezone
      })
    end
  end
end
