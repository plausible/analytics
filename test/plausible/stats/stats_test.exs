defmodule Plausible.StatsTest do
  use Plausible.DataCase
  alias Plausible.Stats
  @user_id UUID.uuid4()

  describe "compare_pageviews_and_visitors" do
    test "comparisons are nil when no historical data" do
      site = insert(:site)
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})
      res = Stats.compare_pageviews_and_visitors(site, query, {10, 10})

      assert res == {nil, nil}
    end

    test "comparisons show percent change with historical data" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 02:00:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-02"})
      {change_pageviews, change_visitors} = Stats.compare_pageviews_and_visitors(site, query, {3, 2})

      assert change_pageviews == 50
      assert change_visitors == 100
    end
  end

  describe "visitors_from_referrer" do
    test "queries for new visitors from a referrer source" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, referrer_source: "Google", new_visitor: true, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", new_visitor: false, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Google", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, referrer_source: "Bing", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})

      assert Stats.visitors_from_referrer(site, query, "Google") == 2
    end
  end

  describe "top_pages" do
    test "shows top 5 pages by pageviews" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, pathname: "/", timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, pathname: "/", timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, pathname: "/hello", timestamp: ~N[2019-01-01 02:00:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})

      assert Stats.top_pages(site, query) == [
        {"/", 2},
        {"/hello", 1}
      ]
    end
  end

  describe "top_screen_sizes" do
    test "shows top screen sizes by new visitors" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, screen_size: "desktop", new_visitor: true, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, screen_size: "desktop", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, screen_size: "mobile", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})

      assert Stats.top_screen_sizes(site, query) == [
        {"mobile", 1},
        {"desktop", 2}
      ]
    end
  end

  describe "countries" do
    test "shows top countries by new visitors" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, country_code: "EE", new_visitor: true, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, country_code: "EE", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, country_code: "GB", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})

      assert Stats.countries(site, query) == [
        {"Estonia", 2},
        {"United Kingdom", 1}
      ]
    end
  end

  describe "browsers" do
    test "shows top browsers by new visitors" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, browser: "Chrome", new_visitor: true, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, browser: "Chrome", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, browser: "Safari", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})

      assert Stats.browsers(site, query) == [
        {"Chrome", 2},
        {"Safari", 1}
      ]
    end
  end

  describe "operating_systems" do
    test "shows top browsers by new visitors" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, operating_system: "Mac", new_visitor: true, timestamp: ~N[2019-01-01 01:00:00])
      insert(:pageview, hostname: site.domain, operating_system: "Windows", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      insert(:pageview, hostname: site.domain, operating_system: "Windows", new_visitor: true, timestamp: ~N[2019-01-01 02:00:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})

      assert Stats.operating_systems(site, query) == [
        {"Windows", 2},
        {"Mac", 1}
      ]
    end
  end

  describe "pageviews_and_visitors" do
    test "counts unique visitors" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 00:00:00])
      insert(:pageview, hostname: site.domain, user_id: @user_id, timestamp: ~N[2019-01-01 23:59:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})
      {pageviews, visitors} = Stats.pageviews_and_visitors(site, query)

      assert pageviews == 2
      assert visitors == 1
    end

    test "does not count custom events" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])
      insert(:event, name: "Custom", hostname: site.domain, timestamp: ~N[2019-01-01 23:59:00])
      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})
      {pageviews, visitors} = Stats.pageviews_and_visitors(site, query)

      assert pageviews == 1
      assert visitors == 1
    end
  end

  describe "calculate_plot" do
    test "displays pageviews for a day" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 00:00:00])
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 23:59:00])

      query = Stats.Query.from(site.timezone, %{"period" => "day", "date" => "2019-01-01"})

      {plot, _labels, _index} = Stats.calculate_plot(site, query)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(22) |> Enum.into([])

      assert Enum.count(plot) == 24
      assert plot == [1] ++ zeroes ++ [1]
    end

    test "displays pageviews for a month" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-01 12:00:00])
      insert(:pageview, hostname: site.domain, timestamp: ~N[2019-01-31 12:00:00])

      query = Stats.Query.from(site.timezone, %{"period" => "month", "date" => "2019-01-01"})
      {plot, _labels, _index} = Stats.calculate_plot(site, query)

      assert Enum.count(plot) == 31
      assert List.first(plot) == 1
      assert List.last(plot) == 1
    end

    test "displays pageviews for a 3 months" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, timestamp: months_ago(2))

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
        timestamp: Timex.now() |> Timex.shift(minutes: -4)
      })

      insert(:pageview, %{
        hostname: site.domain,
        user_id: UUID.uuid4(),
        timestamp: Timex.now() |> Timex.shift(minutes: -6)
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
