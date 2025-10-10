defmodule Plausible.Stats.SamplingTest do
  use Plausible.DataCase, async: true

  use Plausible

  on_ee do
    import Plausible.Stats.Sampling, only: [fractional_sample_rate: 2]
    alias Plausible.Stats.{Query, DateTimeRange}

    describe "&fractional_sample_rate/2" do
      @threshold Plausible.Stats.Sampling.default_sample_threshold()

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
        assert fractional_sample_rate(@threshold * 15, query(1, unit: :hour)) ==
                 :no_sampling
      end

      test "very low sampling rate" do
        assert fractional_sample_rate(@threshold * 500, query(30)) == 0.013
      end

      @filter ["is", "event:name", ["pageview"]]
      test "scales sampling rate according to query filters (when sampling adjustments are enabled)" do
        assert fractional_sample_rate(@threshold * 50, query(30, filters: [])) == 0.02

        assert fractional_sample_rate(@threshold * 50, query(30, filters: [@filter])) ==
                 0.08

        assert fractional_sample_rate(
                 @threshold * 50,
                 query(30, filters: [@filter, @filter])
               ) == 0.32

        assert fractional_sample_rate(
                 @threshold * 50,
                 query(30, filters: [@filter, @filter, @filter])
               ) == 0.32

        assert fractional_sample_rate(
                 @threshold * 10,
                 query(30, filters: [@filter, @filter])
               ) == :no_sampling
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
  end
end
