defmodule Plausible.Stats.SamplingTest do
  use Plausible.DataCase, async: true

  use Plausible

  on_ee do
    import Plausible.Stats.Sampling, only: [fractional_sample_rate: 2]
    alias Plausible.Stats.{Query, DateTimeRange, Sampling}

    describe "&fractional_sample_rate/2" do
      @threshold Sampling.default_sample_threshold()

      test "no traffic estimate" do
        assert fractional_sample_rate(nil, query(30)) == :no_sampling
      end

      test "scales sampling rate according to query duration" do
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
        assert fractional_sample_rate(@threshold * 15, query(1, :hour)) == :no_sampling
      end

      test "very low sampling rate" do
        assert fractional_sample_rate(@threshold * 500, query(30)) == 0.01
      end
    end

    def query(duration, unit \\ :day) do
      first = DateTime.utc_now()
      last = DateTime.add(first, duration, unit)

      %Query{
        utc_time_range: DateTimeRange.new!(first, last),
        timezone: "UTC"
      }
    end
  end
end
