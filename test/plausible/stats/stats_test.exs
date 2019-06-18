defmodule Plausible.StatsTest do
  use Plausible.DataCase
  alias Plausible.Stats

  describe "calculate_plot" do
    test "displays pageviews for a day" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, inserted_at: hours_ago(24))

      query = Stats.Query.from(site.timezone, %{"period" => "day"})

      plot = Stats.calculate_plot(site, query)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(23) |> Enum.into([])

      assert Enum.count(plot) == 25
      assert plot == [1] ++ zeroes ++ [1]
    end

    test "displays pageviews for a week" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, inserted_at: days_ago(7))

      query = Stats.Query.from(site.timezone, %{"period" => "week"})
      plot = Stats.calculate_plot(site, query)


      assert Enum.count(plot) == 8
      assert plot == [1, 0, 0, 0, 0, 0, 0, 1]
    end

    test "displays pageviews for a month" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, inserted_at: days_ago(30))

      query = Stats.Query.from(site.timezone, %{"period" => "month"})

      plot = Stats.calculate_plot(site, query)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(29) |> Enum.into([])

      assert Enum.count(plot) == 31
      assert plot == [1] ++ zeroes ++ [1]
    end

    test "displays pageviews for a 3 months" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, inserted_at: months_ago(3))

      query = Stats.Query.from(site.timezone, %{"period" => "3mo"})

      plot = Stats.calculate_plot(site, query)

      n_days = Timex.diff(Timex.now(), months_ago(3), :days)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(n_days) |> Enum.into([])

      assert Enum.count(plot) == n_days + 2
      assert plot == [1] ++ zeroes ++ [1]
    end
  end

  describe "labels" do
    test "shows last 30 days" do
      query = %Stats.Query{
        date_range: Date.range(~D[2019-01-01], ~D[2019-01-31]),
        step_type: "date"
      }

      labels = Stats.labels(nil, query)

      assert List.first(labels) == "1 Jan"
      assert List.last(labels) == "31 Jan"
    end

    test "shows last 7 days" do
      query = %Stats.Query{
        date_range: Date.range(~D[2019-01-01], ~D[2019-01-08]),
        step_type: "date"
      }

      labels = Stats.labels(nil, query)

      assert List.first(labels) == "1 Jan"
      assert List.last(labels) == "8 Jan"
    end

    test "shows last 24 hours" do
      site = insert(:site)
      query = %Stats.Query{
        date_range: Date.range(~D[2019-01-31], ~D[2019-01-31]),
        step_type: "hour"
      }

      labels = Stats.labels(site, query)
      current_hour = Timex.now() |> Timex.format!("{h12}{am}")

      assert List.first(labels) == current_hour
      assert List.last(labels) == current_hour
    end
  end

  describe "referrer_drilldown" do
    test "shows grouped counts of referrers" do
      site = insert(:site)

      insert(:pageview, %{
        hostname: site.domain,
        referrer: "10words.io/somepage",
        referrer_source: "10words",
        new_visitor: true
      })

      insert(:pageview, %{
        hostname: site.domain,
        referrer: "10words.io/somepage",
        referrer_source: "10words",
        new_visitor: true
      })

      insert(:pageview, %{
        hostname: site.domain,
        referrer: "10words.io/some_other_page",
        referrer_source: "10words",
        new_visitor: true
      })

      query = Stats.Query.from("UTC", %{"period" => "day"})
      drilldown = Stats.referrer_drilldown(site, query, "10words")

      assert {"10words.io/somepage", 2} in drilldown
      assert {"10words.io/some_other_page", 1} in drilldown
    end

    test "counts nil values as a group" do
      site = insert(:site)

      insert(:pageview, %{
        hostname: site.domain,
        referrer: nil,
        referrer_source: "10words",
        new_visitor: true
      })

      insert(:pageview, %{
        hostname: site.domain,
        referrer: nil,
        referrer_source: "10words",
        new_visitor: true
      })

      query = Stats.Query.from("UTC", %{"period" => "day"})
      drilldown = Stats.referrer_drilldown(site, query, "10words")

      assert {nil, 2} in drilldown
    end
  end

  defp months_ago(months) do
    Timex.now() |> Timex.shift(months: -months)
  end

  defp days_ago(days) do
    Timex.now() |> Timex.shift(days: -days)
  end

  defp hours_ago(hours) do
    Timex.now() |> Timex.shift(hours: -hours)
  end
end
