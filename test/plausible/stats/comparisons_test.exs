defmodule Plausible.Stats.ComparisonsTest do
  use Plausible.DataCase
  alias Plausible.Stats.{DateTimeRange, Query, Comparisons}
  import Plausible.TestUtils

  def build_query(site, params, now) do
    query = Query.from(site, params)

    Map.put(query, :now, now)
  end

  describe "with period set to this month" do
    test "shifts back this month period when mode is previous_period" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "month", "date" => "2023-03-02"}, ~N[2023-03-02 14:00:00])

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})

      assert comparison_query.utc_time_range.first == ~U[2023-02-27 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-02-28 23:59:59Z]
    end

    test "shifts back this month period when it's the first day of the month and mode is previous_period" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "month", "date" => "2023-03-01"}, ~N[2023-03-01 14:00:00])

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})

      assert comparison_query.utc_time_range.first == ~U[2023-02-28 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-02-28 23:59:59Z]
    end

    test "matches the day of the week when nearest day is original query start date and mode is previous_period" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "month", "date" => "2023-03-02"}, ~N[2023-03-02 14:00:00])

      comparison_query =
        Comparisons.get_comparison_query(query, %{
          mode: "previous_period",
          match_day_of_week: true
        })

      assert comparison_query.utc_time_range.first == ~U[2023-02-22 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-02-23 23:59:59Z]
    end

    test "custom time zone sets timezone to UTC" do
      site = insert(:site, timezone: "US/Eastern")

      query =
        build_query(site, %{"period" => "month", "date" => "2023-03-02"}, ~N[2023-03-02 14:00:00])

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})

      assert comparison_query.utc_time_range.first == ~U[2023-02-27 05:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-03-01 04:59:59Z]
    end
  end

  describe "with period set to previous month" do
    test "shifts back using the same number of days when mode is previous_period" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "month", "date" => "2023-02-01"}, ~N[2023-03-01 14:00:00])

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})

      assert comparison_query.utc_time_range.first == ~U[2023-01-04 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-01-31 23:59:59Z]
    end

    test "shifts back the full month when mode is year_over_year" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "month", "date" => "2023-02-01"}, ~N[2023-03-01 14:00:00])

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "year_over_year"})

      assert comparison_query.utc_time_range.first == ~U[2022-02-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-02-28 23:59:59Z]
    end

    test "shifts back whole month plus one day when mode is year_over_year and a leap year" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "month", "date" => "2020-02-01"}, ~N[2023-03-01 14:00:00])

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "year_over_year"})

      assert comparison_query.utc_time_range.first == ~U[2019-02-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2019-03-01 23:59:59Z]
    end

    test "matches the day of the week when mode is previous_period keeping the same day" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "month", "date" => "2023-02-01"}, ~N[2023-03-01 14:00:00])

      comparison_query =
        Comparisons.get_comparison_query(query, %{
          mode: "previous_period",
          match_day_of_week: true
        })

      assert comparison_query.utc_time_range.first == ~U[2023-01-04 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-01-31 23:59:59Z]
    end

    test "matches the day of the week when mode is previous_period" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "month", "date" => "2023-01-01"}, ~N[2023-03-01 14:00:00])

      comparison_query =
        Comparisons.get_comparison_query(query, %{
          mode: "previous_period",
          match_day_of_week: true
        })

      assert comparison_query.utc_time_range.first == ~U[2022-12-04 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2023-01-03 23:59:59Z]
    end
  end

  describe "with period set to year to date" do
    test "shifts back by the same number of days when mode is previous_period" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "year", "date" => "2023-03-01"}, ~N[2023-03-01 14:00:00])

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})

      assert comparison_query.utc_time_range.first == ~U[2022-11-02 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-12-31 23:59:59Z]
    end

    test "shifts back by the same number of days when mode is year_over_year" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "year", "date" => "2023-03-01"}, ~N[2023-03-01 14:00:00])

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "year_over_year"})

      assert comparison_query.utc_time_range.first == ~U[2022-01-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-03-01 23:59:59Z]
    end

    test "matches the day of the week when mode is year_over_year" do
      site = insert(:site)

      query =
        build_query(site, %{"period" => "year", "date" => "2023-03-01"}, ~N[2023-03-01 14:00:00])

      comparison_query =
        Comparisons.get_comparison_query(query, %{mode: "year_over_year", match_day_of_week: true})

      assert comparison_query.utc_time_range.first == ~U[2022-01-02 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-03-02 23:59:59Z]
    end
  end

  describe "with period set to previous year" do
    test "shifts back a whole year when mode is year_over_year" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "year", "date" => "2022-03-02"})

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "year_over_year"})

      assert comparison_query.utc_time_range.first == ~U[2021-01-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2021-12-31 23:59:59Z]
    end

    test "shifts back a whole year when mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "year", "date" => "2022-03-02"})

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})

      assert comparison_query.utc_time_range.first == ~U[2021-01-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2021-12-31 23:59:59Z]
    end
  end

  describe "with period set to custom" do
    test "shifts back by the same number of days when mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "custom", "date" => "2023-01-01,2023-01-07"})

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})

      assert comparison_query.utc_time_range.first == ~U[2022-12-25 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-12-31 23:59:59Z]
    end

    test "shifts back to last year when mode is year_over_year" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "custom", "date" => "2023-01-01,2023-01-07"})

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "year_over_year"})

      assert comparison_query.utc_time_range.first == ~U[2022-01-01 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-01-07 23:59:59Z]
    end
  end

  describe "with mode set to custom" do
    test "sets first and last dates" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "custom", "date" => "2023-01-01,2023-01-07"})

      comparison_query =
        Comparisons.get_comparison_query(query, %{
          mode: "custom",
          date_range: DateTimeRange.new!(~U[2022-05-25 00:00:00Z], ~U[2022-05-30 23:59:59Z])
        })

      assert comparison_query.utc_time_range.first == ~U[2022-05-25 00:00:00Z]
      assert comparison_query.utc_time_range.last == ~U[2022-05-30 23:59:59Z]
    end
  end

  describe "include_imported" do
    setup [:create_user, :create_new_site, :create_site_import]

    test "defaults to source_query.include_imported", %{site: site} do
      query = Query.from(site, %{"period" => "day", "date" => "2023-01-01"})
      assert query.include_imported == false

      comparison_query = Comparisons.get_comparison_query(query, %{mode: "previous_period"})
      assert comparison_query.include_imported == false
    end
  end
end
