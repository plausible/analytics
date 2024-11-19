defmodule Plausible.Stats.SamplingCacheTest do
  use Plausible.DataCase, async: true

  use Plausible

  on_ee do
    alias Plausible.Stats.SamplingCache

    describe "getter" do
      test "returns cached values for traffic in past 30 days", %{test: test} do
        now = DateTime.utc_now()

        Plausible.IngestRepo.insert_all(Plausible.Ingestion.Counters.Record, [
          %{
            site_id: 2,
            value: 11_000_000,
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          },
          %{
            site_id: 2,
            value: 11_000_000,
            event_timebucket: add(now, -5, :day),
            metric: "buffered"
          },
          %{
            site_id: 2,
            value: 11_000_000,
            event_timebucket: add(now, -35, :day),
            metric: "buffered"
          },
          %{
            site_id: 3,
            value: 44_000_000,
            event_timebucket: add(now, -35, :day),
            metric: "buffered"
          },
          %{
            site_id: 4,
            value: 11_000_000,
            event_timebucket: add(now, -35, :day),
            metric: "buffered"
          }
        ])

        {:ok, _} = start_test_cache(test)

        assert SamplingCache.get(1) == nil
        assert SamplingCache.get(2) == 22_000_000
        assert SamplingCache.get(3) == nil
        assert SamplingCache.get(4) == nil
      end
    end

    def add(datetime, n, unit) do
      DateTime.add(datetime, n, unit) |> DateTime.truncate(:second)
    end

    defp start_test_cache(cache_name) do
      %{start: {m, f, a}} = SamplingCache.child_spec(cache_name: cache_name)
      apply(m, f, a)
    end
  end
end
