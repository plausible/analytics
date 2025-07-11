defmodule Plausible.Stats.ComparisonsTest do
  use Plausible.DataCase, async: true
  alias Plausible.Stats.{Query, Comparisons}
  import Plausible.TestUtils

  setup [:create_user, :create_site]

  def build_query(site, params, now) do
    Query.from(site, params, %{}, now)
  end

  describe "with period set to this month" do
    test "shifts back this month period when mode is previous_period", %{site: site} do
      query =
        build_query(
          site,
          %{"period" => "month", "date" => "2023-03-02", "comparison" => "previous_period"},
          ~U[2023-03-02 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2023-02-27 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-02-28 23:59:59Z]
    end

    test "shifts back this month period when it's the first day of the month and mode is previous_period",
         %{site: site} do
      query =
        build_query(
          site,
          %{"period" => "month", "date" => "2023-03-01", "comparison" => "previous_period"},
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2023-02-28 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-02-28 23:59:59Z]
    end

    test "matches the day of the week when nearest day is original query start date and mode is previous_period",
         %{site: site} do
      query =
        build_query(
          site,
          %{
            "period" => "month",
            "date" => "2023-03-02",
            "comparison" => "previous_period",
            "match_day_of_week" => "true"
          },
          ~U[2023-03-02 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2023-02-22 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-02-23 23:59:59Z]
    end

    test "custom time zone sets timezone to UTC" do
      site = insert(:site, timezone: "US/Eastern")

      query =
        build_query(
          site,
          %{"period" => "month", "date" => "2023-03-02", "comparison" => "previous_period"},
          ~U[2023-03-02 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2023-02-27 05:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-03-01 04:59:59Z]
    end
  end

  describe "with period set to previous month" do
    test "shifts back using the same number of days when mode is previous_period", %{site: site} do
      query =
        build_query(
          site,
          %{"period" => "month", "date" => "2023-02-01", "comparison" => "previous_period"},
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2023-01-04 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-01-31 23:59:59Z]
    end

    test "shifts back the full month when mode is year_over_year", %{site: site} do
      query =
        build_query(
          site,
          %{"period" => "month", "date" => "2023-02-01", "comparison" => "year_over_year"},
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2022-02-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-02-28 23:59:59Z]
    end

    test "shifts back whole month plus one day when mode is year_over_year and a leap year", %{
      site: site
    } do
      query =
        build_query(
          site,
          %{"period" => "month", "date" => "2020-02-01", "comparison" => "year_over_year"},
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2019-02-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2019-03-01 23:59:59Z]
    end

    test "matches the day of the week when mode is previous_period keeping the same day", %{
      site: site
    } do
      query =
        build_query(
          site,
          %{
            "period" => "month",
            "date" => "2023-02-01",
            "comparison" => "previous_period",
            "match_day_of_week" => "true"
          },
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2023-01-04 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-01-31 23:59:59Z]
    end

    test "matches the day of the week when mode is previous_period", %{site: site} do
      query =
        build_query(
          site,
          %{
            "period" => "month",
            "date" => "2023-01-01",
            "comparison" => "previous_period",
            "match_day_of_week" => "true"
          },
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2022-12-04 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-01-03 23:59:59Z]
    end
  end

  describe "year_over_year, exact dates behavior with leap years" do
    test "start of the year matching", %{site: site} do
      query =
        Query.from(site, %{
          "period" => "7d",
          "date" => "2021-01-05",
          "comparison" => "year_over_year"
        })

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2019-12-29 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2020-01-04 23:59:59Z]
      assert date_range_length(comparison_query) == 7
    end

    test "leap day matching", %{site: site} do
      query =
        Query.from(site, %{
          "period" => "7d",
          "date" => "2021-03-04",
          "comparison" => "year_over_year"
        })

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2020-02-25 00:00:00Z]
      # :TRICKY: Since dates of the two months don't match precisely we cut off earlier
      assert comparison_query.utc_time_range.last == ~U[2020-03-02 23:59:59Z]
      assert date_range_length(comparison_query) == 7
    end

    test "end of the year matching", %{site: site} do
      query =
        Query.from(site, %{
          "period" => "7d",
          "date" => "2021-11-25",
          "comparison" => "year_over_year"
        })

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2020-11-18 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2020-11-24 23:59:59Z]
      assert date_range_length(comparison_query) == 7
    end
  end

  describe "with period set to year to date" do
    test "shifts back by the same number of days when mode is previous_period", %{site: site} do
      query =
        build_query(
          site,
          %{"period" => "year", "date" => "2023-03-01", "comparison" => "previous_period"},
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2022-11-02 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-12-31 23:59:59Z]
    end

    test "shifts back by the same number of days when mode is year_over_year", %{site: site} do
      query =
        build_query(
          site,
          %{"period" => "year", "date" => "2023-03-01", "comparison" => "year_over_year"},
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2022-01-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-03-01 23:59:59Z]
    end

    test "matches the day of the week when mode is year_over_year", %{site: site} do
      query =
        build_query(
          site,
          %{
            "period" => "year",
            "date" => "2023-03-01",
            "comparison" => "year_over_year",
            "match_day_of_week" => "true"
          },
          ~U[2023-03-01 14:00:00Z]
        )

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2022-01-02 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-03-02 23:59:59Z]
    end
  end

  describe "with period set to previous year" do
    test "shifts back a whole year when mode is year_over_year", %{site: site} do
      query =
        Query.from(site, %{
          "period" => "year",
          "date" => "2022-03-02",
          "comparison" => "year_over_year"
        })

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2021-01-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2021-12-31 23:59:59Z]
    end

    test "shifts back a whole year when mode is previous_period", %{site: site} do
      query =
        Query.from(site, %{
          "period" => "year",
          "date" => "2022-03-02",
          "comparison" => "previous_period"
        })

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2021-01-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2021-12-31 23:59:59Z]
    end
  end

  describe "with period set to custom" do
    test "shifts back by the same number of days when mode is previous_period", %{site: site} do
      query =
        Query.from(site, %{
          "period" => "custom",
          "date" => "2023-01-01,2023-01-07",
          "comparison" => "previous_period"
        })

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2022-12-25 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-12-31 23:59:59Z]
    end

    test "shifts back to last year when mode is year_over_year", %{site: site} do
      query =
        Query.from(site, %{
          "period" => "custom",
          "date" => "2023-01-01,2023-01-07",
          "comparison" => "year_over_year"
        })

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2022-01-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-01-07 23:59:59Z]
    end
  end

  describe "with mode set to custom" do
    test "sets first and last dates", %{site: site} do
      query =
        Query.from(site, %{
          "period" => "custom",
          "date" => "2023-01-01,2023-01-07",
          "comparison" => "custom",
          "compare_from" => "2022-05-25",
          "compare_to" => "2022-05-30"
        })

      comparison_query = Comparisons.get_comparison_query(query)

      assert comparison_query.utc_time_range.first == ~U[2022-05-25 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-05-30 23:59:59Z]
    end
  end

  describe "add_comparison_filters" do
    test "no results doesn't update filters", %{site: site} do
      query = build_comparison_query(site, %{"dimensions" => ["visit:browser"]})

      result_query = Comparisons.add_comparison_filters(query, [])

      assert result_query.filters == []
    end

    test "no dimensions doesn't update filters", %{site: site} do
      query = build_comparison_query(site, %{})

      result_query =
        Comparisons.add_comparison_filters(query, [%{dimensions: [], metrics: [123]}])

      assert result_query.filters == []
    end

    test "no time dimension doesn't update filters", %{site: site} do
      query = build_comparison_query(site, %{"dimensions" => ["time:day"]})

      result_query =
        Comparisons.add_comparison_filters(query, [%{dimensions: ["2024-01-01"], metrics: [123]}])

      assert result_query.filters == []
    end

    test "updates filters in a single-row case", %{site: site} do
      query =
        build_comparison_query(site, %{
          "dimensions" => ["visit:browser"]
        })

      result_query =
        Comparisons.add_comparison_filters(query, [%{dimensions: ["Chrome"], metrics: [123]}])

      assert result_query.filters == [
               [:ignore_in_totals_query, [:is, "visit:browser", ["Chrome"]]]
             ]
    end

    test "updates filters for a complex case", %{site: site} do
      query =
        build_comparison_query(site, %{
          "dimensions" => ["visit:browser", "visit:browser_version", "time:day"],
          "filters" => [["is", "visit:country_name", ["Estonia"]]]
        })

      main_query_results = [
        %{
          dimensions: ["Chrome", "99.9", "2024-01-01"],
          metrics: [123]
        },
        %{
          dimensions: ["Firefox", "12.0", "2024-01-01"],
          metrics: [123]
        }
      ]

      result_query = Comparisons.add_comparison_filters(query, main_query_results)

      assert result_query.filters == [
               [:is, "visit:country_name", ["Estonia"]],
               [
                 :ignore_in_totals_query,
                 [
                   :or,
                   [
                     [
                       :and,
                       [
                         [:is, "visit:browser", ["Chrome"]],
                         [:is, "visit:browser_version", ["99.9"]]
                       ]
                     ],
                     [
                       :and,
                       [
                         [:is, "visit:browser", ["Firefox"]],
                         [:is, "visit:browser_version", ["12.0"]]
                       ]
                     ]
                   ]
                 ]
               ]
             ]
    end
  end

  defp build_comparison_query(site, params) do
    {:ok, query} =
      Query.build(
        site,
        :internal,
        Map.merge(
          %{
            "site_id" => site.domain,
            "metrics" => ["pageviews"],
            "date_range" => ["2024-01-01", "2024-02-01"],
            "include" => %{"comparisons" => %{"mode" => "previous_period"}}
          },
          params
        ),
        %{}
      )

    query
  end

  def date_range_length(query) do
    query
    |> Query.date_range()
    |> Enum.count()
  end
end
