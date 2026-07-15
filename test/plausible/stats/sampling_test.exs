defmodule Plausible.Stats.SamplingTest do
  use Plausible.DataCase, async: false

  on_ee do
    import Plausible.Stats.Sampling, only: [fractional_sample_rate: 2]
    alias Plausible.Stats.{Query, DateTimeRange}

    @threshold Plausible.Stats.Sampling.default_sample_threshold()

    describe "&fractional_sample_rate/2 for date ranges of different lengths" do
      test "no traffic estimate" do
        assert fractional_sample_rate(nil, query(30)) == :no_sampling
      end

      test "scales sampling rate according to query duration" do
        for n <- [1, 100, 1000, 10_000, 100_000, 1_000_000, 7_000_000] do
          assert {n, fractional_sample_rate(n, query(1))} == {n, :no_sampling}
          assert {n, fractional_sample_rate(n, query(5))} == {n, :no_sampling}
          assert {n, fractional_sample_rate(n, query(10))} == {n, :no_sampling}
          assert {n, fractional_sample_rate(n, query(15))} == {n, :no_sampling}
          assert {n, fractional_sample_rate(n, query(30))} == {n, :no_sampling}
          assert {n, fractional_sample_rate(n, query(60))} == {n, :no_sampling}
          assert {n, fractional_sample_rate(n, query(100))} == {n, :no_sampling}
        end

        assert fractional_sample_rate(6_000_000, query(300)) == 0.17
        assert fractional_sample_rate(7_500_000, query(100)) == 0.4
        assert fractional_sample_rate(7_500_000, query(364)) == 0.11
        assert fractional_sample_rate(7_500_000, query(900)) == 0.04
        assert fractional_sample_rate(7_500_000, query(2900)) == 0.013

        assert fractional_sample_rate(@threshold * 2, query(30)) == :no_sampling
        assert fractional_sample_rate(@threshold * 2, query(60)) == 0.25
        assert fractional_sample_rate(@threshold * 2, query(100)) == 0.15

        assert fractional_sample_rate(@threshold * 5, query(1)) == :no_sampling
        assert fractional_sample_rate(@threshold * 5, query(5)) == :no_sampling
        assert fractional_sample_rate(@threshold * 5, query(10)) == :no_sampling
        assert fractional_sample_rate(@threshold * 5, query(15)) == 0.40
        assert fractional_sample_rate(@threshold * 5, query(30)) == 0.20
        assert fractional_sample_rate(@threshold * 5, query(60)) == 0.10
        assert fractional_sample_rate(@threshold * 5, query(100)) == 0.06

        assert fractional_sample_rate(@threshold * 15, query(2)) == :no_sampling
        assert fractional_sample_rate(@threshold * 15, query(5)) == 0.40
        assert fractional_sample_rate(@threshold * 15, query(10)) == 0.20
      end

      test "short durations" do
        assert fractional_sample_rate(@threshold * 15, query(1, unit: :hour)) == :no_sampling
      end

      test "very low sampling rate" do
        assert fractional_sample_rate(@threshold * 500, query(30)) == 0.013
      end

      @filter ["is", "event:name", ["pageview"]]
      test "scales sampling rate according to query filters (when sampling adjustments are enabled)" do
        assert fractional_sample_rate(@threshold * 50, query(30, filters: [])) == 0.02
        assert fractional_sample_rate(@threshold * 50, query(30, filters: [@filter])) == 0.08

        assert fractional_sample_rate(@threshold * 50, query(30, filters: [@filter, @filter])) ==
                 0.32

        assert fractional_sample_rate(
                 @threshold * 50,
                 query(30, filters: [@filter, @filter, @filter])
               ) == 0.32

        assert fractional_sample_rate(@threshold * 10, query(30, filters: [@filter, @filter])) ==
                 :no_sampling
      end
    end

    describe "&fractional_sample_rate/2 clamps the range to the site's stats start" do
      test "a range with no known stats start uses the full requested range" do
        # `site_native_stats_start_at` is only nil in tests / for sites without
        # stats; nothing gets clamped, matching a stats start before the range.
        without_start = range_query(~D[2025-01-01], ~D[2026-07-15], nil)
        early_start = range_query(~D[2025-01-01], ~D[2026-07-15], ~N[1900-01-01 00:00:00])

        assert fractional_sample_rate(@threshold, without_start) ==
                 fractional_sample_rate(@threshold, early_start)
      end

      test "a range starting after stats begin is unaffected by the clamp" do
        after_start = range_query(~D[2026-04-01], ~D[2026-07-15], ~N[2026-01-01 00:00:00])
        no_start = range_query(~D[2026-04-01], ~D[2026-07-15], nil)

        assert fractional_sample_rate(@threshold, after_start) ==
                 fractional_sample_rate(@threshold, no_start)
      end

      test "a range starting before stats begin is treated as starting when stats begin" do
        stats_start = ~N[2026-01-01 00:00:00]
        range_end = ~D[2026-07-15]

        from_stats_start =
          fractional_sample_rate(@threshold, range_query(~D[2026-01-01], range_end, stats_start))

        from_1970 =
          fractional_sample_rate(@threshold, range_query(~D[1970-01-01], range_end, stats_start))

        from_2025 =
          fractional_sample_rate(@threshold, range_query(~D[2025-01-01], range_end, stats_start))

        assert from_stats_start == 0.15
        assert from_1970 == from_stats_start
        assert from_2025 == from_stats_start
      end
    end

    describe "&fractional_sample_rate/2 for sites with less than 30 days of stats" do
      test "estimates traffic from the site's real daily rate, not a 30-day average" do
        # Site started 3 days before "now" (2026-07-15) and has ingested 30M
        # events since (10M/day). A query over the last 30 days is clamped to
        # those 3 days, where all 30M events live - 3x the sampling threshold -
        # so it must be sampled.
        query = range_query(~D[2026-06-15], ~D[2026-07-15], ~N[2026-07-12 00:00:00])

        assert fractional_sample_rate(30_000_000, query) == 0.33
      end
    end

    def query(duration, opts \\ []) do
      unit = Keyword.get(opts, :unit, :day)
      filters = Keyword.get(opts, :filters, [])

      first = DateTime.utc_now()
      last = DateTime.add(first, duration, unit)

      %Query{
        utc_time_range: DateTimeRange.new!(first, last),
        timezone: "UTC",
        filters: filters
      }
    end

    defp range_query(first_date, last_date, native_stats_start_at) do
      first = DateTime.new!(first_date, ~T[00:00:00], "Etc/UTC")
      last = DateTime.new!(last_date, ~T[00:00:00], "Etc/UTC")

      %Query{
        utc_time_range: DateTimeRange.new!(first, last),
        timezone: "UTC",
        filters: [],
        now: last,
        site_native_stats_start_at: native_stats_start_at
      }
    end
  end
end
