defmodule Plausible.InternalStatsApiVersionTest do
  use ExUnit.Case, async: true

  alias Plausible.InternalStatsApiVersion

  describe "api_version/0" do
    test "returns a non-negative integer" do
      assert is_integer(InternalStatsApiVersion.api_version())
      assert InternalStatsApiVersion.api_version() >= 0
    end
  end

  describe "effective_version/0" do
    test "equals api_version in single-node setup" do
      assert InternalStatsApiVersion.effective_version() ==
               InternalStatsApiVersion.api_version()
    end
  end

  describe "cluster_min/1" do
    test "returns the minimum integer from results" do
      assert InternalStatsApiVersion.cluster_min([3, 2, 2]) == 2
    end

    test "ignores non-integer results" do
      assert InternalStatsApiVersion.cluster_min([{:badrpc, :timeout}, 2, 3]) == 2
    end

    test "falls back to local api_version when all results are non-integer" do
      assert InternalStatsApiVersion.cluster_min([{:badrpc, :timeout}]) ==
               InternalStatsApiVersion.api_version()
    end

    test "falls back to local api_version for empty results" do
      assert InternalStatsApiVersion.cluster_min([]) ==
               InternalStatsApiVersion.api_version()
    end
  end
end
