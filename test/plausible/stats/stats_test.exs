defmodule Plausible.StatsTest do
  use Plausible.DataCase
  alias Plausible.Stats

  describe "calculate_plot" do
    test "displays pageviews for a day" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, inserted_at: ~N[2019-01-01 00:00:00])
      insert(:pageview, hostname: site.domain, inserted_at: ~N[2019-01-01 23:59:00])

      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})

      {plot, _labels, _index} = Stats.calculate_plot(site, query)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(22) |> Enum.into([])

      assert Enum.count(plot) == 24
      assert plot == [1] ++ zeroes ++ [1]
    end

    test "displays pageviews for a month" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, inserted_at: ~N[2019-01-01 12:00:00])
      insert(:pageview, hostname: site.domain, inserted_at: ~N[2019-01-31 12:00:00])

      query = Stats.Query.from(site.timezone, %{"period" => "month", "date" => "2019-01-01"})
      {plot, _labels, _index} = Stats.calculate_plot(site, query)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 1
      assert List.last(plot) == 1
    end

    test "displays pageviews for a 3 months" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, inserted_at: months_ago(2))

      query = Stats.Query.from(site.timezone, %{"period" => "3mo"})
      {plot, _labels, _index} = Stats.calculate_plot(site, query)

      assert Enum.count(plot) == 3
      assert plot == [1, 0, 1]
    end
  end

  describe "labels" do
    test "shows last 30 days" do
      site = insert(:site)

      query = %Stats.Query{
        date_range: Date.range(~D[2019-01-01], ~D[2019-01-31]),
        step_type: "date"
      }

      {_plot, labels, _index} = Stats.calculate_plot(site, query)

      assert List.first(labels) == "2019-01-01"
      assert List.last(labels) == "2019-01-31"
    end

    test "shows last 7 days" do
      site = insert(:site)
      query = %Stats.Query{
        date_range: Date.range(~D[2019-01-01], ~D[2019-01-08]),
        step_type: "date"
      }

      {_plot, labels, _index} = Stats.calculate_plot(site, query)

      assert List.first(labels) == "2019-01-01"
      assert List.last(labels) == "2019-01-08"
    end

    test "shows last 24 hours" do
      site = insert(:site)
      query = %Stats.Query{
        period: "day",
        date_range: Date.range(~D[2019-01-31], ~D[2019-01-31]),
        step_type: "hour"
      }

      {_plot, labels, _index} = Stats.calculate_plot(site, query)

      assert List.first(labels) == "2019-01-31T00:00:00"
      assert List.last(labels) == "2019-01-31T23:00:00"
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

  describe "current_visitors" do
    test "counts user ids seen in the last 5 minutes" do
      site = insert(:site)

      insert(:pageview, %{
        hostname: site.domain,
        user_id: UUID.uuid4(),
      })

      insert(:pageview, %{
        hostname: site.domain,
        user_id: UUID.uuid4(),
        inserted_at: Timex.now() |> Timex.shift(minutes: -4)
      })

      insert(:pageview, %{
        hostname: site.domain,
        user_id: UUID.uuid4(),
        inserted_at: Timex.now() |> Timex.shift(minutes: -6)
      })

      assert Stats.current_visitors(site) == 2
    end

    test "counts unique user ids" do
      site = insert(:site)
      id = UUID.uuid4()

      insert(:pageview, %{
        hostname: site.domain,
        user_id: id,
      })

      insert(:pageview, %{
        hostname: site.domain,
        user_id: id,
      })

      assert Stats.current_visitors(site) == 1
    end
  end

  defp months_ago(months) do
    Timex.now() |> Timex.shift(months: -months)
  end
end
