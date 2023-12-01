defmodule Plausible.RateLimitTest do
  use ExUnit.Case, async: true
  alias Plausible.RateLimit

  @table __MODULE__

  defp key, do: "key:#{System.unique_integer([:positive])}"

  @tag :slow
  test "garbage collection" do
    start_supervised!({RateLimit, clean_period: _100_ms = 100, table: @table})

    key = key()
    scale = _50_ms = 50
    limit = 10

    for _ <- 1..3 do
      assert {:allow, 1} = RateLimit.check_rate(@table, key, scale, limit)
      assert [{{^key, _bucket}, _count = 1, expires_at}] = :ets.tab2list(@table)

      assert expires_at > System.system_time(:millisecond)
      assert expires_at <= System.system_time(:millisecond) + 50

      :timer.sleep(150)

      assert :ets.tab2list(@table) == []
    end
  end

  describe "check_rate/3" do
    setup do
      start_supervised!({RateLimit, clean_period: :timer.minutes(1), table: @table})
      :ok
    end

    test "increments" do
      key = key()
      scale = :timer.seconds(10)
      limit = 10

      assert {:allow, 1} = RateLimit.check_rate(@table, key, scale, limit)
      assert {:allow, 2} = RateLimit.check_rate(@table, key, scale, limit)
      assert {:allow, 3} = RateLimit.check_rate(@table, key, scale, limit)
    end

    test "resets" do
      key = key()
      scale = 10
      limit = 10

      assert {:allow, 1} = RateLimit.check_rate(@table, key, scale, limit)
      :timer.sleep(scale * 2 + 1)
      assert {:allow, 1} = RateLimit.check_rate(@table, key, scale, limit)
    end

    test "denies" do
      key = key()
      scale = :timer.seconds(10)
      limit = 3

      assert {:allow, 1} = RateLimit.check_rate(@table, key, scale, limit)
      assert {:allow, 2} = RateLimit.check_rate(@table, key, scale, limit)
      assert {:allow, 3} = RateLimit.check_rate(@table, key, scale, limit)
      assert {:deny, 3} = RateLimit.check_rate(@table, key, scale, limit)
    end
  end
end
