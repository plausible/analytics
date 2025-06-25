defmodule Plausible.Stats.SamplingTest do
  use Plausible.DataCase, async: true

  use Plausible

  on_ee do
    import Plausible.Stats.Sampling, only: [fractional_sample_rate: 3]
    alias Plausible.Stats.{Query, DateTimeRange, Sampling}

    describe "&fractional_sample_rate/2" do
      @threshold Sampling.default_sample_threshold()

      test "no traffic estimate" do
        assert fractional_sample_rate(nil, query(30), false) == :no_sampling
      end

      test "scales sampling rate according to query duration" do
        assert fractional_sample_rate(@threshold * 2, query(30), false) == :no_sampling
        assert fractional_sample_rate(@threshold * 2, query(60), false) == 0.25
        assert fractional_sample_rate(@threshold * 2, query(100), false) == 0.15

        assert fractional_sample_rate(@threshold * 5, query(1), false) == :no_sampling
        assert fractional_sample_rate(@threshold * 5, query(5), false) == :no_sampling
        assert fractional_sample_rate(@threshold * 5, query(10), false) == :no_sampling
        assert fractional_sample_rate(@threshold * 5, query(15), false) == 0.40
        assert fractional_sample_rate(@threshold * 5, query(30), false) == 0.20
        assert fractional_sample_rate(@threshold * 5, query(60), false) == 0.10
        assert fractional_sample_rate(@threshold * 5, query(100), false) == 0.06

        assert fractional_sample_rate(@threshold * 15, query(2), false) == :no_sampling
        assert fractional_sample_rate(@threshold * 15, query(5), false) == 0.40
        assert fractional_sample_rate(@threshold * 15, query(10), false) == 0.20
      end

      test "short durations" do
        assert fractional_sample_rate(@threshold * 15, query(1, unit: :hour), false) ==
                 :no_sampling
      end

      test "very low sampling rate" do
        assert fractional_sample_rate(@threshold * 500, query(30), false) == 0.01
        assert fractional_sample_rate(@threshold * 500, query(30), true) == 0.013
      end

      @filter ["is", "event:name", ["pageview"]]
      test "scales sampling rate according to query filters (when sampling adjustments are enabled)" do
        assert fractional_sample_rate(@threshold * 50, query(30, filters: []), true) == 0.02

        assert fractional_sample_rate(@threshold * 50, query(30, filters: [@filter]), true) ==
                 0.40

        assert fractional_sample_rate(
                 @threshold * 50,
                 query(30, filters: [@filter, @filter]),
                 true
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
