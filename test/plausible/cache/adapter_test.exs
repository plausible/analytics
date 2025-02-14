defmodule Plausible.Cache.AdapterTest do
  use Plausible.DataCase, async: false

  alias Plausible.Cache.Adapter

  describe "adapter - partitioning" do
    test "multiple partitions are routed to", %{test: test} do
      name = :cache_partitions_test

      iterations = 100
      partitions = 4

      patch_env(Adapter, [{name, partitions: partitions}])

      {:ok, _} =
        Supervisor.start_link(
          Adapter.child_specs(name, name, []),
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      for i <- 1..iterations, do: Adapter.put(name, i, i)

      assert Adapter.size(name) == iterations

      for i <- 1..iterations, do: assert(Adapter.get(name, i) == i)

      assert name |> Adapter.keys() |> Enum.sort() == Enum.to_list(1..iterations)

      for i <- 1..partitions do
        assert ConCache.size(:"#{name}_#{i}") > 0
        assert ConCache.size(:"#{name}_#{i}") < iterations
      end

      assert {:ok, %{hit_rate: 100.0, count: ^iterations}} = Plausible.Cache.Stats.gather(name)
    end
  end
end
