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

      half = div(iterations, 2)
      for i <- 1..half, do: Adapter.put(name, i, i)
      Adapter.put_many(name, for(i <- half..iterations, do: {i, i}))

      assert Adapter.size(name) == iterations

      for i <- 1..iterations, do: assert(Adapter.get(name, i) == i)

      assert name |> Adapter.keys() |> Enum.sort() == Enum.to_list(1..iterations)

      for i <- 1..partitions do
        assert ConCache.size(:"#{name}_#{i}") > 0
        assert ConCache.size(:"#{name}_#{i}") < iterations
      end

      assert ^iterations = Plausible.Cache.Adapter.size(name)
    end
  end

  describe "ets type: bag" do
    test "put_many/2 removes dupe keys", %{test: test} do
      name = :bag_of_keys

      {:ok, _} =
        Supervisor.start_link(
          Adapter.child_specs(name, name, [ets_options: [:bag]]),
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      Adapter.put_many(name, [{1, :one}, {1, :one_dupe}, {2, :two}])
      assert Adapter.size(name) == 3
      assert Adapter.get(name, 1) == [:one, :one_dupe]
      assert Adapter.get(name, 2) == :two

      Adapter.put_many(name, [{1, :just_one}])

      assert Adapter.size(name) == 2
      assert Adapter.get(name, 1) == :just_one
      assert Adapter.get(name, 2) == :two
    end
  end
end
