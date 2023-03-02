defmodule Plausible.Stats.ComparisonsTest do
  use Plausible.DataCase
  alias Plausible.Stats.{Query, Comparisons}

  describe "previous_period" do
    test "shifts back this month period" do
      site = build(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-03-01"})
      now = ~N[2023-03-01 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "previous_period", now)

      assert comparison.date_range.first == ~D[2023-02-27]
      assert comparison.date_range.last == ~D[2023-02-28]
    end
  end

  describe "year over year" do
    test "shifts back this month period" do
      site = build(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-03-02"})
      now = ~N[2023-03-02 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "year_over_year", now)

      assert comparison.date_range.first == ~D[2022-03-01]
      assert comparison.date_range.last == ~D[2022-03-02]
    end

    test "shifts back last month period" do
      site = build(:site)
      query = Query.from(site, %{"period" => "month", "date" => "2023-02-02"})
      now = ~N[2023-03-02 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "year_over_year", now)

      assert comparison.date_range.first == ~D[2022-02-01]
      assert comparison.date_range.last == ~D[2022-02-28]
    end

    test "shifts back this year period" do
      site = build(:site)
      query = Query.from(site, %{"period" => "year", "date" => "2023-03-01"})
      now = ~N[2023-03-02 14:00:00]

      {:ok, comparison} = Comparisons.compare(site, query, "year_over_year", now)

      assert comparison.date_range.first == ~D[2022-01-01]
      assert comparison.date_range.last == ~D[2022-03-02]
    end
  end
end
