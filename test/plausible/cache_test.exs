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
  end

  describe "stats tracking" do
    test "get affects hit rate", %{test: test} do
      {:ok, _} = start_test_cache(test)
      :ok = ExampleCache.merge_items([{"item1", :item1}], cache_name: test)
      assert ExampleCache.get("item1", cache_name: test, force?: true)
      assert {:ok, %{hit_rate: 100.0}} = Plausible.Cache.Stats.gather(test)
      refute ExampleCache.get("item2", cache_name: test, force?: true)
      assert {:ok, %{hit_rate: 50.0}} = Plausible.Cache.Stats.gather(test)
    end

    test "get_or_store affects hit rate", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = ExampleCache.merge_items([{"item1", :item1}], cache_name: test)
      assert ExampleCache.get("item1", cache_name: test, force?: true)

      # first read of item2 is evaluated from a function and stored
      assert "value" ==
               ExampleCache.get_or_store("item2", fn -> "value" end,
                 cache_name: test,
                 force?: true
               )

      # subsequent gets are read from cache and the function is disregarded
      assert "value" ==
               ExampleCache.get_or_store("item2", fn -> "disregard" end,
                 cache_name: test,
                 force?: true
               )

      assert "value" ==
               ExampleCache.get_or_store("item2", fn -> "disregard" end,
                 cache_name: test,
                 force?: true
               )

      # 3 hits, 1 miss
      assert {:ok, %{hit_rate: 75.0}} = Plausible.Cache.Stats.gather(test)
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
  end

  defp report_back(test_pid) do
    fn opts ->
      send(test_pid, {:cache_warmed, %{at: System.monotonic_time(), opts: opts}})
      :ok
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
