defmodule Plausible.Stats.SamplingCacheTest do
  use Plausible.DataCase, async: true

  use Plausible

  on_ee do
    alias Plausible.Stats.SamplingCache

    @site_id1 100_000
    @site_id2 200_000
    @site_id3 300_000
    @site_id4 400_000

    describe "getter" do
      test "returns cached values for traffic in past 30 days", %{test: test} do
        now = DateTime.utc_now()

        Plausible.IngestRepo.insert_all(Plausible.Ingestion.Counters.Record, [
          %{
            site_id: @site_id1,
            domain: "1.com",
            value: 11_000_000,
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id2,
            domain: "2.com",
            value: 11_000_000,
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id2,
            domain: "2.com",
            value: 11_000_000,
            event_timebucket: add(now, -5, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id2,
            domain: "2.com",
            value: 11_000_000,
            event_timebucket: add(now, -35, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id3,
            domain: "3.com",
            value: 44_000_000,
            event_timebucket: add(now, -35, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id4,
            domain: "4.com",
            value: 11_000_000,
            event_timebucket: add(now, -35, :day),
            metric: "buffered"
          }
        ])

        start_test_cache(test)

        assert SamplingCache.count_all() == 1
        assert SamplingCache.get(@site_id1, force?: true, cache_name: test) == nil
        assert SamplingCache.get(@site_id2, force?: true, cache_name: test) == 22_000_000
        assert SamplingCache.get(@site_id3, force?: true, cache_name: test) == nil
        assert SamplingCache.get(@site_id4, force?: true, cache_name: test) == nil

        Plausible.IngestRepo.insert_all(Plausible.Ingestion.Counters.Record, [
          %{
            site_id: @site_id1,
            value: 11_000_000,
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          }
        ])

        :ok = SamplingCache.refresh_all(cache_name: test)

        assert SamplingCache.count_all() == 2
        assert SamplingCache.get(@site_id1, force?: true, cache_name: test) == 22_000_000
        assert SamplingCache.get(@site_id2, force?: true, cache_name: test) == 22_000_000
      end
    end

    def add(datetime, n, unit) do
      DateTime.add(datetime, n, unit) |> DateTime.truncate(:second)
    end

    defp start_test_cache(cache_name) do
      %{start: {m, f, a}} = SamplingCache.child_spec(cache_name: cache_name)
      apply(m, f, a)

      :ok = SamplingCache.refresh_all(cache_name: cache_name)
    end
  end
end
