defmodule Plausible.Session.Transfer.AliveTest do
  use ExUnit.Case, async: true
  import Plausible.TestUtils, only: [tmp_dir: 0]
  alias Plausible.Session.Transfer.{Alive, TinySock}

  @tag :slow
  test "it works" do
    tmp_dir = tmp_dir()

    # once the count drops to 0
    # the alive process should exit.
    # until then tinysock is alive
    counter = :counters.new(1, [])
    :counters.add(counter, 1, 1)

    pid =
      :proc_lib.spawn(fn ->
        {:ok, sup} =
          Supervisor.start_link(
            [
              {TinySock, base_path: tmp_dir, handler: fn :alive -> :yes end},
              {Alive, _until = fn -> :counters.get(counter, 1) == 0 end}
            ],
            strategy: :one_for_one
          )

        receive do
          :shutdown -> Supervisor.stop(sup, :shutdown, :infinity)
        end
      end)

    # start shutdown and wait for a second
    send(pid, :shutdown)
    :timer.sleep(:timer.seconds(1))
    assert Process.alive?(pid)

    # check if tinysock is still alive, it should be
    assert [sock] = TinySock.list!(tmp_dir)
    assert {:ok, :yes} = TinySock.call(sock, :alive)

    # now decrement the counter and wait for another second
    :counters.add(counter, 1, -1)
    :timer.sleep(:timer.seconds(1))
    refute Process.alive?(pid)

    # check if tinysock is still alive, it shouldn't be
    assert TinySock.list!(tmp_dir) == []
    assert {:error, :enoent} = TinySock.call(sock, :alive)
  end
end
