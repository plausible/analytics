defmodule Plausible.Session.ReplaySaltsTest do
  use Plausible.DataCase, async: false
  use Plausible

  on_ee do
    alias Plausible.Session.ReplaySalts

    test "agent starts and responds with salt based on provided session id" do
      {:ok, _} = ReplaySalts.start_link(name: __MODULE__)
      %{current: current, previous: nil} = ReplaySalts.fetch(__MODULE__, 123_123_123)
      assert is_binary(current)
    end

    test "agent starts and responds with the same salt for the same session id" do
      {:ok, _} = ReplaySalts.start_link(name: __MODULE__)
      %{current: current1, previous: nil} = ReplaySalts.fetch(__MODULE__, 123_123_123)
      %{current: current2, previous: nil} = ReplaySalts.fetch(__MODULE__, 123_123_123)
      assert is_binary(current1)
      assert current1 == current2
    end

    test "agent starts and responds with a different salt for different session ids" do
      {:ok, _} = ReplaySalts.start_link(name: __MODULE__)
      %{current: current1, previous: nil} = ReplaySalts.fetch(__MODULE__, 123_123_123)
      %{current: current2, previous: nil} = ReplaySalts.fetch(__MODULE__, 123_123_124)
      assert is_binary(current1)
      assert is_binary(current2)
      assert current1 != current2
    end

    test "salts are cached and cache can be purged" do
      {:ok, _} = ReplaySalts.start_link(name: __MODULE__)
      %{current: salt_before_purge, previous: nil} = ReplaySalts.fetch(__MODULE__, 123_123_123)
      %{current: _, previous: nil} = ReplaySalts.fetch(__MODULE__, 123_123_124)

      assert [_, _] = :ets.tab2list(__MODULE__)

      send(__MODULE__, :purge)

      assert eventually(fn ->
               table = :ets.tab2list(__MODULE__)
               {table == [], table}
             end)

      %{current: salt_after_purge, previous: nil} = ReplaySalts.fetch(__MODULE__, 123_123_123)

      assert [_] = :ets.tab2list(__MODULE__)

      assert salt_before_purge == salt_after_purge
    end
  end
end
