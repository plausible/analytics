defmodule Plausible.CacheTest do
  use Plausible.DataCase, async: true

  alias Plausible.Cache
  import ExUnit.CaptureLog

  defmodule ExampleCache do
    use Plausible.Cache

    def name(), do: __MODULE__
    def child_id(), do: __MODULE__
    def count_all(), do: 100

    def base_db_query() do
      %Ecto.Query{}
    end

    def get_from_source("existing_key") do
      :from_source
    end

    def get_from_source(_) do
      nil
    end
  end

  defmodule UnavailableRepo do
    def all(_query) do
      raise DBConnection.ConnectionError, "connection not available and request was dropped"
    end
  end

  defmodule UnavailableCache do
    use Plausible.Cache

    def name(), do: __MODULE__
    def child_id(), do: __MODULE__
    def count_all(), do: 100
    def repo(), do: UnavailableRepo
    def base_db_query(), do: %Ecto.Query{}
    def get_from_source(key), do: repo().all(key)
  end

  describe "public cache interface" do
    test "cache process is started, but falls back to the database if cache is disabled", %{
      test: test
    } do
      {:ok, _} =
        Supervisor.start_link(
          [{ExampleCache, [cache_name: ExampleCache.name(), child_id: test]}],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      insert(:site, domain: "example.test")
      refute Cache.enabled?()
      assert Process.alive?(Process.whereis(ExampleCache.name()))
      refute Process.whereis(ExampleCache.Warmer)
      assert :from_source = ExampleCache.get("existing_key")
      assert ExampleCache.size() == 0
      refute ExampleCache.get("other.test")
    end

    test "critical cache errors are logged and nil is returned" do
      log =
        capture_log(fn ->
          assert ExampleCache.get("key", force?: true, cache_name: NonExistingCache) == nil
        end)

      assert log =~ "Error retrieving key from 'NonExistingCache'"
    end

    test "cache is not ready when it doesn't exist", %{test: test} do
      refute ExampleCache.ready?(test)
    end

    test "refresh_all returns an error when the database is unavailable", %{test: test} do
      assert {:error, %DBConnection.ConnectionError{}} =
               UnavailableCache.refresh_all(cache_name: test)
    end
  end

  describe "merging cache items" do
    test "merging adds new items", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = ExampleCache.merge_items([{"item1", :item1}], cache_name: test)
      assert :item1 == ExampleCache.get("item1", cache_name: test, force?: true)
    end

    test "merging no new items leaves the old cache intact", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = ExampleCache.merge_items([{"item1", :item1}], cache_name: test)
      :ok = ExampleCache.merge_items([], cache_name: test)
      assert :item1 == ExampleCache.get("item1", cache_name: test, force?: true)
    end

    test "merging removes stale items", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = ExampleCache.merge_items([{"item1", :item1}], cache_name: test)
      :ok = ExampleCache.merge_items([{"item2", :item2}], cache_name: test)

      refute ExampleCache.get("item1", cache_name: test, force?: true)
      assert ExampleCache.get("item2", cache_name: test, force?: true)
    end

    test "merging optionally leaves stale items intact", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = ExampleCache.merge_items([{"item1", :item1}], cache_name: test)

      :ok =
        ExampleCache.merge_items([{"item2", :item2}],
          cache_name: test,
          delete_stale_items?: false
        )

      assert ExampleCache.get("item1", cache_name: test, force?: true)
      assert ExampleCache.get("item2", cache_name: test, force?: true)
    end

    test "merging updates changed items", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok =
        ExampleCache.merge_items([{"item1", :item1}, {"item2", :item2}],
          cache_name: test
        )

      :ok =
        ExampleCache.merge_items([{"item1", :changed}, {"item2", :item2}],
          cache_name: test
        )

      assert :changed == ExampleCache.get("item1", cache_name: test, force?: true)
      assert :item2 == ExampleCache.get("item2", cache_name: test, force?: true)
    end

    test "put puts into local cache, overwriting as appropriate", %{test: test} do
      {:ok, _} = start_test_cache(test)
      opts = [cache_name: test, force?: true]
      assert ExampleCache.put("key", :item1, opts)
      assert ExampleCache.get("key", opts) == :item1
      assert ExampleCache.put("key", :updated, opts)
      assert ExampleCache.get("key", opts) == :updated
    end

    test "broadcast_put puts into local cache", %{test: test} do
      {:ok, _} = start_test_cache(test)
      :ok = ExampleCache.broadcast_put("item1", :item1, cache_name: test)

      assert eventually(fn ->
               {ExampleCache.get("item1", cache_name: test, force?: true) == :item1, :ok}
             end)
    end

    test "broadcast_delete deletes from local cache", %{test: test} do
      {:ok, _} = start_test_cache(test)
      :item1 = ExampleCache.put("item1", :item1, cache_name: test)
      :ok = ExampleCache.broadcast_delete("item1", cache_name: test)

      assert eventually(fn ->
               {ExampleCache.get("item1", cache_name: test, force?: true) == nil, :ok}
             end)
    end
  end

  describe "warming the cache" do
    test "cache warmer process warms up the cache", %{test: test} do
      test_pid = self()

      opts = [
        cache_impl: ExampleCache,
        force_start?: true,
        warmer_fn: report_back(test_pid),
        cache_name: test,
        interval: 30
      ]

      {:ok, _} =
        Supervisor.start_link([{Plausible.Cache.Warmer, opts}],
          strategy: :one_for_one,
          name: test
        )

      assert Process.whereis(Plausible.Cache.Warmer)

      assert_receive {:cache_warmed, %{opts: got_opts}}
      assert got_opts[:cache_name] == test
    end

    test "cache warmer warms periodically with an interval", %{test: test} do
      test_pid = self()

      opts = [
        cache_impl: ExampleCache,
        force_start?: true,
        warmer_fn: report_back(test_pid),
        cache_name: test,
        interval: 30
      ]

      {:ok, _} = start_test_warmer(opts)

      assert_receive {:cache_warmed, %{at: at1}}, 100
      assert_receive {:cache_warmed, %{at: at2}}, 100
      assert_receive {:cache_warmed, %{at: at3}}, 100

      assert is_integer(at1)
      assert is_integer(at2)
      assert is_integer(at3)

      assert at1 < at2
      assert at3 > at2
    end

    test "cache warmer backs off retries until it succeeds, then stops", %{test: test} do
      opts = [
        cache_impl: ExampleCache,
        force_start?: true,
        warmer_fn: fail_first(self(), 3),
        cache_name: test,
        interval: :timer.hours(1),
        retry_interval: 60,
        max_retries: 4
      ]

      capture_log(fn ->
        {:ok, _} = start_test_warmer(opts)

        warmed_at =
          for _ <- 1..4 do
            assert_receive {:cache_warmed, %{at: at}}, 1000
            at
          end

        scheduling_tolerance = 100

        for {[previous_at, at], backoff} <-
              Enum.zip(Enum.chunk_every(warmed_at, 2, 1, :discard), [60, 120, 240]) do
          elapsed = System.convert_time_unit(at - previous_at, :native, :millisecond)

          assert elapsed >= backoff
          assert elapsed <= backoff + div(backoff, 3) + scheduling_tolerance
        end

        refute_receive {:cache_warmed, _}, 800
      end)
    end

    test "cache warmer stops retrying after a few failed retries", %{test: test} do
      opts = [
        cache_impl: ExampleCache,
        force_start?: true,
        warmer_fn: report_back(self(), {:error, :db_unavailable}),
        cache_name: test,
        interval: :timer.hours(1),
        retry_interval: 10
      ]

      errors =
        capture_log([level: :error], fn ->
          {:ok, _} = start_test_warmer(opts)

          for _ <- 1..4, do: assert_receive({:cache_warmed, _}, 1000)
          refute_receive {:cache_warmed, _}, 300
        end)

      assert [_] = Regex.scan(~r/failed - :db_unavailable/, errors)
    end

    for max_retries <- [0, 1, 4] do
      test "cache warmer stops after #{max_retries} configured retries", %{test: test} do
        max_retries = unquote(max_retries)

        opts = [
          cache_impl: ExampleCache,
          force_start?: true,
          warmer_fn: report_back(self(), {:error, :db_unavailable}),
          cache_name: test,
          interval: :timer.hours(1),
          retry_interval: 10,
          max_retries: max_retries
        ]

        capture_log(fn ->
          {:ok, _} = start_test_warmer(opts)

          for _ <- 0..max_retries, do: assert_receive({:cache_warmed, _}, 1000)
          refute_receive {:cache_warmed, _}, 300
        end)
      end
    end

    test "cache warmer ignores a pending retry after a regular cycle", %{test: test} do
      opts = [
        cache_impl: ExampleCache,
        force_start?: true,
        warmer_fn: fail_first(self(), 1),
        cache_name: test,
        interval: :timer.hours(1),
        retry_interval: 300
      ]

      log =
        capture_log(fn ->
          {:ok, warmer} = start_test_warmer(opts)
          assert_receive {:cache_warmed, _}, 1000

          send(warmer, :"$cycle")
          assert_receive {:cache_warmed, _}, 1000

          refute_receive {:cache_warmed, _}, 600
        end)

      assert log =~ "retrying in"
    end

    test "cache warmer does not retry a failing run without a retry interval", %{test: test} do
      opts = [
        cache_impl: ExampleCache,
        force_start?: true,
        warmer_fn: report_back(self(), {:error, :db_unavailable}),
        cache_name: test,
        interval: :timer.hours(1)
      ]

      capture_log(fn ->
        {:ok, _} = start_test_warmer(opts)

        assert_receive {:cache_warmed, _}, 1000
        refute_receive {:cache_warmed, _}, 200
      end)
    end

    test "cache warmer does not retry a successful run", %{test: test} do
      test_pid = self()

      opts = [
        cache_impl: ExampleCache,
        force_start?: true,
        warmer_fn: report_back(test_pid),
        cache_name: test,
        interval: :timer.hours(1),
        retry_interval: 30
      ]

      {:ok, _} = start_test_warmer(opts)

      assert_receive {:cache_warmed, _}, 1000
      refute_receive {:cache_warmed, _}, 150
    end
  end

  defp report_back(test_pid, result \\ :ok) do
    fn opts ->
      send(test_pid, {:cache_warmed, %{at: System.monotonic_time(), opts: opts}})
      result
    end
  end

  defp fail_first(test_pid, times) do
    runs = :counters.new(1, [])

    fn opts ->
      :counters.add(runs, 1, 1)
      result = if :counters.get(runs, 1) <= times, do: {:error, :db_unavailable}, else: :ok
      report_back(test_pid, result).(opts)
    end
  end

  defp start_test_warmer(opts) do
    child_name_opt = {:child_name, Keyword.fetch!(opts, :cache_name)}
    %{start: {m, f, a}} = Cache.Warmer.child_spec([child_name_opt | opts])
    apply(m, f, a)
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = ExampleCache.child_spec(cache_name: cache_name)
    apply(m, f, a)
  end
end
