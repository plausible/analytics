defmodule Plausible.Cache.StatsTest do
  use Plausible.DataCase, async: true

  alias Plausible.Cache.Stats

  test "when tracking is not initialized, stats are 0" do
    assert {:ok, %{hit_rate: +0.0, count: 0}} = Stats.gather(:foo)
  end

  test "when cache is started, stats are 0", %{test: test} do
    {:ok, _} = Stats.start_link(name: test, table: test)
    assert {:ok, %{hit_rate: +0.0, count: 0}} = Stats.gather(test, test)
  end

  test "tracking changes hit ratio", %{test: test} do
    {:ok, _} = Stats.start_link(name: test, table: test)

    Stats.track(nil, test, test)
    assert {:ok, %{hit_rate: +0.0, count: 0}} = Stats.gather(test, test)

    Stats.track(:not_nil, test, test)
    assert {:ok, %{hit_rate: 50.0, count: 0}} = Stats.gather(test, test)

    Stats.track(:not_nil, test, test)
    Stats.track(:not_nil, test, test)
    assert {:ok, %{hit_rate: 75.0, count: 0}} = Stats.gather(test, test)

    Stats.track(nil, test, test)
    Stats.track(nil, test, test)
    assert {:ok, %{hit_rate: 50.0, count: 0}} = Stats.gather(test, test)
  end

  test "bump by custom number", %{test: test} do
    {:ok, _} = Stats.start_link(name: test, table: test)
    Stats.bump(test, :miss, 10, test)
    assert {:ok, %{hit_rate: +0.0, count: 0}} = Stats.gather(test, test)
    Stats.bump(test, :hit, 90, test)
    assert {:ok, %{hit_rate: 90.0, count: 0}} = Stats.gather(test, test)
  end

  test "count comes from cache adapter", %{test: test} do
    {:ok, _} = Stats.start_link(name: test, table: test)
    %{start: {m, f, a}} = Plausible.Cache.Adapter.child_spec(test, test)
    {:ok, _} = apply(m, f, a)

    Plausible.Cache.Adapter.put(test, :key, :value)
    assert Stats.size(test) == 1
    assert {:ok, %{hit_rate: +0.0, count: 1}} = Stats.gather(test, test)
  end
end
