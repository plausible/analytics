defmodule Plausible.StatsTest do
  use Plausible.DataCase
  alias Plausible.Stats

  describe "calculate_plot" do
    test "displays pageviews for 24h" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, inserted_at: hours_ago(24))

      query = Stats.Query.from(site.timezone, %{"period" => "24h"})

      plot = Stats.calculate_plot(site, query)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(23) |> Enum.into([])

      assert Enum.count(plot) == 25
      assert plot == [1] ++ zeroes ++ [1]
    end

    test "displays pageviews for 7d" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, inserted_at: days_ago(7))

      query = Stats.Query.from(site.timezone, %{"period" => "7d"})

      plot = Stats.calculate_plot(site, query)


      assert Enum.count(plot) == 8
      assert plot == [1, 0, 0, 0, 0, 0, 0, 1]
    end

    test "displays pageviews for 30d" do
      site = insert(:site)
      insert(:pageview, hostname: site.domain)
      insert(:pageview, hostname: site.domain, inserted_at: days_ago(31)) # TODO: Why is the symmetry broken? In the previous test we don't have to n+1 the insertion date

      query = Stats.Query.from(site.timezone, %{"period" => "30d"})

      plot = Stats.calculate_plot(site, query)

      zeroes = Stream.repeatedly(fn -> 0 end) |> Stream.take(29) |> Enum.into([])

      assert Enum.count(plot) == 31
      assert plot == [1] ++ zeroes ++ [1]
    end
  end

  defp days_ago(days) do
    Timex.now() |> Timex.shift(days: -days)
  end

  defp hours_ago(hours) do
    Timex.now() |> Timex.shift(hours: -hours)
  end
end
