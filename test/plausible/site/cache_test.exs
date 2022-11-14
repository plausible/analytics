defmodule Plausible.Site.CacheTest do
  use Plausible.DataCase, async: true

  alias Plausible.Site
  alias Plausible.Site.Cache

  import ExUnit.CaptureLog

  test "cache process is started, but falls back to the database if cache is disabled" do
    insert(:site, domain: "example.test")
    refute Cache.enabled?()
    assert Process.alive?(Process.whereis(Cache.name()))
    refute Process.whereis(Cache.Warmer)
    assert %Site{domain: "example.test", from_cache?: false} = Cache.get("example.test")
    assert Cache.size() == 0
    refute Cache.get("other.test")
  end

  test "cache warmer process warms up the cache", %{test: test} do
    test_pid = self()
    opts = [force_start?: true, warmer_fn: report_back(test_pid), cache_name: test]

    {:ok, _} = Supervisor.start_link([{Cache.Warmer, opts}], strategy: :one_for_one, name: test)

    assert Process.whereis(Cache.Warmer)
    assert_receive {:cache_warmed, %{opts: got_opts}}
    assert got_opts[:cache_name] == test
  end

  test "cache warmer sends telemetry event", %{test: test} do
    test_pid = self()

    :telemetry.attach(
      "test-cache-warmer",
      Cache.Warmer.telemetry_event_refresh(test),
      fn _event, %{duration: d}, %{}, %{} when is_integer(d) ->
        send(test_pid, :telemetry_handled)
      end,
      %{}
    )

    opts = [force_start?: true, warmer_fn: report_back(test_pid), cache_name: test]
    {:ok, _} = Supervisor.start_link([{Cache.Warmer, opts}], strategy: :one_for_one, name: test)

    assert_receive {:cache_warmed, _}
    assert_receive :telemetry_handled
  end

  test "critical cache errors are logged and nil is returned" do
    log =
      capture_log(fn ->
        assert Cache.get("key", force?: true, cache_name: NonExistingCache) == nil
      end)

    assert log =~ "Error retrieving 'key' from 'NonExistingCache': :no_cache"
  end

  test "cache warmer warms periodically with an interval", %{test: test} do
    test_pid = self()
    opts = [force_start?: true, warmer_fn: report_back(test_pid), cache_name: test, interval: 30]

    {:ok, _} = Supervisor.start_link([{Cache.Warmer, opts}], strategy: :one_for_one, name: test)

    assert_receive {:cache_warmed, %{at: at1}}, 100
    assert_receive {:cache_warmed, %{at: at2}}, 100
    assert_receive {:cache_warmed, %{at: at3}}, 100

    assert is_integer(at1)
    assert is_integer(at2)
    assert is_integer(at3)

    assert at1 < at2
    assert at3 > at2
  end

  test "cache caches", %{test: test} do
    {:ok, _} =
      Supervisor.start_link([{Cache, [cache_name: test, child_id: :test_cache_caches_id]}],
        strategy: :one_for_one,
        name: Test.Supervisor.Cache
      )

    %{id: first_id} = site1 = insert(:site, domain: "site1.example.com")
    _ = insert(:site, domain: "site2.example.com")

    :ok = Cache.prefill(cache_name: test)

    {:ok, _} = Plausible.Repo.delete(site1)

    assert Cache.size(test) == 2

    assert %Site{from_cache?: true, id: ^first_id} =
             Cache.get("site1.example.com", force?: true, cache_name: test)

    assert %Site{from_cache?: true} =
             Cache.get("site2.example.com", force?: true, cache_name: test)

    assert %Site{from_cache?: false} = Cache.get("site2.example.com", cache_name: test)

    refute Cache.get("site3.example.com", cache_name: test, force?: true)
  end

  test "cache exposes hit rate", %{test: test} do
    {:ok, _} =
      Supervisor.start_link([{Cache, [cache_name: test, child_id: :test_cache_caches_id]}],
        strategy: :one_for_one,
        name: Test.Supervisor.HitRateCache
      )

    insert(:site, domain: "site1.example.com")
    :ok = Cache.prefill(cache_name: test)

    assert Cache.hit_rate(test) == 0
    assert Cache.get("site1.example.com", force?: true, cache_name: test)
    assert Cache.hit_rate(test) == 100
    refute Cache.get("nonexisting.example.com", force?: true, cache_name: test)
    assert Cache.hit_rate(test) == 50
  end

  defp report_back(test_pid) do
    fn opts ->
      send(test_pid, {:cache_warmed, %{at: System.monotonic_time(), opts: opts}})
      :ok
    end
  end
end
