defmodule Plausible.Stats.SamplingCacheTest do
  use Plausible.DataCase, async: true

  use Plausible

  on_ee do
    alias Plausible.Stats.SamplingCache

    @site_id1 100_000
    @site_id2 200_000
    @site_id3 300_000
    @site_id4 400_000
    @site_id5 500_000
    @site_id6 600_000
    @site_id7 700_000
    @site_id8 800_000
    @site_id9 900_000

    setup do
      Plausible.IngestRepo.query!("truncate ingest_counters")

      on_exit(fn ->
        Plausible.IngestRepo.query!("truncate ingest_counters")
      end)

      :ok
    end

    describe "getter" do
      @threshold Plausible.Stats.Sampling.default_sample_threshold()

      test "returns cached values for traffic in past 30 days", %{test: test} do
        now = DateTime.utc_now()

        {6, _} =
          Plausible.IngestRepo.insert_all(Plausible.Ingestion.Counters.Record, [
            %{
              site_id: @site_id1,
              domain: "1.com",
              value: (@threshold * 0.55) |> trunc(),
              event_timebucket: add(now, -1, :day),
              metric: "buffered"
            },
            %{
              site_id: @site_id2,
              domain: "2.com",
              value: (@threshold * 0.55) |> trunc(),
              event_timebucket: add(now, -1, :day),
              metric: "buffered"
            },
            %{
              site_id: @site_id2,
              domain: "2.com",
              value: (@threshold * 0.55) |> trunc(),
              event_timebucket: add(now, -5, :day),
              metric: "buffered"
            },
            %{
              site_id: @site_id2,
              domain: "2.com",
              value: (@threshold * 0.55) |> trunc(),
              event_timebucket: add(now, -35, :day),
              metric: "buffered"
            },
            %{
              site_id: @site_id3,
              domain: "3.com",
              value: (@threshold * 2.05) |> trunc(),
              event_timebucket: add(now, -35, :day),
              metric: "buffered"
            },
            %{
              site_id: @site_id4,
              domain: "4.com",
              value: (@threshold * 0.55) |> trunc(),
              event_timebucket: add(now, -35, :day),
              metric: "buffered"
            }
          ])

        start_test_cache(test)

        assert SamplingCache.get(@site_id1, force?: true, cache_name: test) == 5_500_000
        assert SamplingCache.get(@site_id2, force?: true, cache_name: test) == 1.1 * @threshold
        assert SamplingCache.get(@site_id3, force?: true, cache_name: test) == nil
        assert SamplingCache.get(@site_id4, force?: true, cache_name: test) == nil

        Plausible.IngestRepo.insert_all(Plausible.Ingestion.Counters.Record, [
          %{
            site_id: @site_id1,
            value: (@threshold * 0.55) |> trunc(),
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          }
        ])

        :ok = SamplingCache.refresh_all(cache_name: test)

        assert SamplingCache.get(@site_id1, force?: true, cache_name: test) == 1.1 * @threshold
        assert SamplingCache.get(@site_id2, force?: true, cache_name: test) == 1.1 * @threshold
      end

      test "returns cached values for traffic in past 30 days for consolidated site", %{
        test: test
      } do
        now = DateTime.utc_now()

        Plausible.IngestRepo.insert_all(Plausible.Ingestion.Counters.Record, [
          %{
            site_id: @site_id5,
            domain: "5.com",
            value: (@threshold * 0.55) |> trunc(),
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id5,
            domain: "5.com",
            value: (@threshold * 0.55) |> trunc(),
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id6,
            domain: "6.com",
            value: (@threshold * 0.55) |> trunc(),
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id6,
            domain: "6.com",
            value: (@threshold * 0.55) |> trunc(),
            event_timebucket: add(now, -5, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id6,
            domain: "6.com",
            value: (@threshold * 0.55) |> trunc(),
            event_timebucket: add(now, -35, :day),
            metric: "buffered"
          }
        ])

        start_test_cache(test)

        assert SamplingCache.consolidated_get([@site_id5, @site_id6],
                 cache_name: test,
                 force?: true
               ) == 1.1 * @threshold * 2
      end

      test "consolidated_get sum over threshold", %{
        test: test
      } do
        now = DateTime.utc_now()

        Plausible.IngestRepo.insert_all(Plausible.Ingestion.Counters.Record, [
          %{
            site_id: @site_id7,
            domain: "7.com",
            value: div(@threshold, 2),
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id8,
            domain: "8.com",
            value: div(@threshold, 2),
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          },
          %{
            site_id: @site_id9,
            domain: "9.com",
            value: div(@threshold, 2),
            event_timebucket: add(now, -1, :day),
            metric: "buffered"
          }
        ])

        start_test_cache(test)

        assert SamplingCache.consolidated_get([@site_id7, @site_id8],
                 cache_name: test,
                 force?: true
               ) == @threshold

        assert SamplingCache.consolidated_get([@site_id9],
                 cache_name: test,
                 force?: true
               ) == div(@threshold, 2)
      end

      test "conslidated_get returns nil", %{test: test} do
        start_test_cache(test)

        assert is_nil(
                 SamplingCache.consolidated_get([@site_id5, @site_id6],
                   cache_name: test,
                   force?: true
                 )
               )
      end
    end

    defp add(datetime, n, unit) do
      DateTime.add(datetime, n, unit) |> DateTime.truncate(:second)
    end

    defp start_test_cache(cache_name) do
      %{start: {m, f, a}} = SamplingCache.child_spec(cache_name: cache_name)

      {:ok, _pid} = apply(m, f, a)
      :ok = SamplingCache.refresh_all(cache_name: cache_name)
    end
  end
end
