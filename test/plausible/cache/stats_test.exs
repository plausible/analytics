defmodule Plausible.Cache.StatsTest do
  use Plausible.DataCase, async: true

  alias Plausible.Cache.Stats

  test "when tracking is not initialized, stats are 0" do
    assert {:ok, %{hit_rate: +0.0, count: 0}} = Stats.gather(:foo)
  end

  test "when cache is started, stats are 0", %{test: test} do
    assert {:ok, %{hit_rate: +0.0, count: 0}} = Stats.gather(test)
  end

  test "tracking changes hit ratio", %{test: test} do
    Stats.record_miss(test)
    assert {:ok, %{hit_rate: +0.0, count: 0}} = Stats.gather(test)

    Stats.record_hit(test)
    assert {:ok, %{hit_rate: 50.0, count: 0}} = Stats.gather(test)

    Stats.record_hit(test)
    Stats.record_hit(test)
    assert {:ok, %{hit_rate: 75.0, count: 0}} = Stats.gather(test)

    Stats.record_miss(test)
    Stats.record_miss(test)
    assert {:ok, %{hit_rate: 50.0, count: 0}} = Stats.gather(test)
  end

  test "hit ratio goes up to 100", %{test: test} do
    Stats.record_hit(test)
    Stats.record_hit(test)
    Stats.record_hit(test)
    assert {:ok, %{hit_rate: 100.0, count: 0}} = Stats.gather(test)
  end

  test "count comes from cache adapter", %{test: test} do
    %{start: {m, f, a}} = Plausible.Cache.Adapter.child_spec(test, test)
    {:ok, _} = apply(m, f, a)

    Plausible.Cache.Adapter.put(test, :key, :value)
    assert Stats.size(test) == 1
    assert {:ok, %{hit_rate: +0.0, count: 1}} = Stats.gather(test)
  end
end
