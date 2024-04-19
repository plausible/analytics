defmodule Plausible.Stats.ComparisonsTest do
  use Plausible.DataCase
  alias Plausible.Stats.{Query, Comparisons}
  import Plausible.TestUtils

  describe "with period set to this month" do
    test "shifts back this month period when mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-03-02"})
      now = ~N[2023-03-02 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "previous_period", now: now)

      assert comparison.date_range.first == ~D[2023-02-27]
      assert comparison.date_range.last == ~D[2023-02-28]
    end

    test "shifts back this month period when it's the first day of the month and mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-03-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "previous_period", now: now)

      assert comparison.date_range.first == ~D[2023-02-28]
      assert comparison.date_range.last == ~D[2023-02-28]
    end

    test "matches the day of the week when nearest day is original query start date and mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-03-02"})
      now = ~N[2023-03-02 14:00:00]

      {:ok, comparison} =
        Comparisons.compare(site, query, "previous_period", now: now, match_day_of_week?: true)

      assert comparison.date_range.first == ~D[2023-02-22]
      assert comparison.date_range.last == ~D[2023-02-23]
    end
  end

  describe "with period set to previous month" do
    test "shifts back using the same number of days when mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-02-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "previous_period", now: now)

      assert comparison.date_range.first == ~D[2023-01-04]
      assert comparison.date_range.last == ~D[2023-01-31]
    end

    test "shifts back the full month when mode is year_over_year" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-02-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "year_over_year", now: now)

      assert comparison.date_range.first == ~D[2022-02-01]
      assert comparison.date_range.last == ~D[2022-02-28]
    end

    test "shifts back whole month plus one day when mode is year_over_year and a leap year" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2020-02-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "year_over_year", now: now)

      assert comparison.date_range.first == ~D[2019-02-01]
      assert comparison.date_range.last == ~D[2019-03-01]
    end

    test "matches the day of the week when mode is previous_period keeping the same day" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-02-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} =
        Comparisons.compare(site, query, "previous_period", now: now, match_day_of_week?: true)

      assert comparison.date_range.first == ~D[2023-01-04]
      assert comparison.date_range.last == ~D[2023-01-31]
    end

    test "matches the day of the week when mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-01-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} =
        Comparisons.compare(site, query, "previous_period", now: now, match_day_of_week?: true)

      assert comparison.date_range.first == ~D[2022-12-04]
      assert comparison.date_range.last == ~D[2023-01-03]
    end
  end

  describe "with period set to year to date" do
    test "shifts back by the same number of days when mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "year", "date" => "2023-03-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "previous_period", now: now)

      assert comparison.date_range.first == ~D[2022-11-02]
      assert comparison.date_range.last == ~D[2022-12-31]
    end

    test "shifts back by the same number of days when mode is year_over_year" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "year", "date" => "2023-03-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "year_over_year", now: now)

      assert comparison.date_range.first == ~D[2022-01-01]
      assert comparison.date_range.last == ~D[2022-03-01]
    end

    test "matches the day of the week when mode is year_over_year" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "year", "date" => "2023-03-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} =
        Comparisons.compare(site, query, "year_over_year", now: now, match_day_of_week?: true)

      assert comparison.date_range.first == ~D[2022-01-02]
      assert comparison.date_range.last == ~D[2022-03-02]
    end
  end

  describe "with period set to previous year" do
    test "shifts back a whole year when mode is year_over_year" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "year", "date" => "2022-03-02"})

      {:ok, comparison} = Comparisons.compare(site, query, "year_over_year")

      assert comparison.date_range.first == ~D[2021-01-01]
      assert comparison.date_range.last == ~D[2021-12-31]
    end

    test "shifts back a whole year when mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "year", "date" => "2022-03-02"})

      {:ok, comparison} = Comparisons.compare(site, query, "previous_period")

      assert comparison.date_range.first == ~D[2021-01-01]
      assert comparison.date_range.last == ~D[2021-12-31]
    end
  end

  describe "with period set to custom" do
    test "shifts back by the same number of days when mode is previous_period" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "custom", "date" => "2023-01-01,2023-01-07"})

      {:ok, comparison} = Comparisons.compare(site, query, "previous_period")

      assert comparison.date_range.first == ~D[2022-12-25]
      assert comparison.date_range.last == ~D[2022-12-31]
    end

    test "shifts back to last year when mode is year_over_year" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "custom", "date" => "2023-01-01,2023-01-07"})

      {:ok, comparison} = Comparisons.compare(site, query, "year_over_year")

      assert comparison.date_range.first == ~D[2022-01-01]
      assert comparison.date_range.last == ~D[2022-01-07]
    end
  end

  describe "with mode set to custom" do
    test "sets first and last dates" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "custom", "date" => "2023-01-01,2023-01-07"})

      {:ok, comparison} =
        Comparisons.compare(site, query, "custom", from: "2022-05-25", to: "2022-05-30")

      assert comparison.date_range.first == ~D[2022-05-25]
      assert comparison.date_range.last == ~D[2022-05-30]
    end

    test "validates from and to dates" do
      site = insert(:site)
      query = Query.from(site, %{"period" => "custom", "date" => "2023-01-01,2023-01-07"})

      assert {:error, :invalid_dates} ==
               Comparisons.compare(site, query, "custom", from: "2022-05-41", to: "2022-05-30")

      assert {:error, :invalid_dates} ==
               Comparisons.compare(site, query, "custom", from: "2022-05-30", to: "2022-05-25")
    end
  end

  describe "include_imported" do
    setup [:create_user, :create_new_site, :create_site_import]

    test "defaults to source_query.include_imported", %{site: site} do
      query = Query.from(site, %{"period" => "day", "date" => "2023-01-01"})
      assert query.include_imported == false

      {:ok, comparison_query} = Comparisons.compare(site, query, "previous_period")
      assert comparison_query.include_imported == false
    end
  end
end
