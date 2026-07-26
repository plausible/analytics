defmodule Plausible.Stats.SamplingTest do
  use Plausible.DataCase, async: false

  on_ee do
    import Plausible.Stats.Sampling, only: [fractional_sample_rate: 2, queried_duration_days: 1]
    alias Plausible.Stats.{Query, DateTimeRange}

    @threshold Plausible.Stats.Sampling.default_sample_threshold()

    describe "&queried_duration_days/1" do
      test "handles 1 day range" do
        query = range_query(~D[2026-07-20], ~D[2026-07-20], ~N[2000-01-01 00:00:00])

        assert queried_duration_days(query) == 1
      end

      test "handles range in non-leap year" do
        query = range_query(~D[2025-01-01], ~D[2025-12-31], ~N[2000-01-01 00:00:00])

        assert queried_duration_days(query) == 365
      end

      test "handles range in leap year" do
        query = range_query(~D[2024-01-01], ~D[2024-12-31], ~N[2000-01-01 00:00:00])

        assert queried_duration_days(query) == 366
      end

      test "is clamped to the site's native stats start for a range extending beyond native stats start" do
        query = range_query(~D[2026-07-01], ~D[2026-07-10], ~N[2026-07-08 00:00:00])

        # Stats begin Jul 8, range ends Jul 10 -> Jul 8, 9, 10 = 3 days.
        assert queried_duration_days(query) == 3
      end
    end

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

    describe "&fractional_sample_rate/2 clamping" do
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

      test "sample rate is correct if a site has ingested 30M events in the 3 days it has existed" do
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
        timezone: "Etc/UTC",
        filters: filters,
        now: last,
        # A stats start well before the range, so nothing gets clamped.
        site_native_stats_start_at: ~N[2000-01-01 00:00:00]
      }
    end

    defp range_query(first_date, last_date, native_stats_start_at) do
      utc_time_range = DateTimeRange.new!(first_date, last_date, "Etc/UTC")

      %Query{
        utc_time_range: utc_time_range,
        timezone: "Etc/UTC",
        filters: [],
        now: utc_time_range.last,
        site_native_stats_start_at: native_stats_start_at
      }
    end
  end
end
