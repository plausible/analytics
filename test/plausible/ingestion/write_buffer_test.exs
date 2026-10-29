defmodule Plausible.Ingestion.WriteBufferTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Plausible.Ingestion.WriteBuffer

  @compile_time_opts WriteBuffer.compile_time_prepare(Plausible.ClickhouseEventV2)

  test "keeps running and logs the reason when a linked process exits", %{test: test} do
    opts = [
      header: @compile_time_opts.header,
      insert_sql: @compile_time_opts.insert_sql,
      insert_opts: @compile_time_opts.insert_opts,
      # unique atom is at our disposal already
      name: test,
      # no need to ever flush automatically on slow CI
      flush_interval_ms: 1_000_000_000
    ]

    {:ok, pid} = WriteBuffer.start_link(opts)

    # The buffer traps exits, so a linked process exiting delivers a real
    # {:EXIT, from, reason} message to handle_info/2. Linking a throwaway
    # process to the buffer and killing it reproduces the crash in #6382
    # without sending a synthetic message.
    child =
      spawn(fn ->
        Process.link(pid)
        Process.sleep(:infinity)
      end)

    ref = Process.monitor(child)

    log =
      capture_log(fn ->
        Process.exit(child, :shutdown)
        assert_receive {:DOWN, ^ref, :process, ^child, _}, 1_000
        assert Process.alive?(pid)
        assert WriteBuffer.flush(test) == :ok
      end)

    assert log =~ "received EXIT, keeping buffer alive"
    assert log =~ ":shutdown"
  end

  test "ignores a stale tick left in the mailbox by a cancelled timer", %{test: test} do
    opts = [
      header: @compile_time_opts.header,
      insert_sql: @compile_time_opts.insert_sql,
      insert_opts: @compile_time_opts.insert_opts,
      name: test,
      flush_interval_ms: 1_000_000_000
    ]

    {:ok, pid} = WriteBuffer.start_link(opts)

    %{timer: {_, current_ref}} = :sys.get_state(pid)

    # a tick from an earlier, already cancelled timer
    send(pid, {:tick, make_ref()})
    assert %{timer: {_, ^current_ref}} = :sys.get_state(pid)

    # the current tick still reschedules
    send(pid, {:tick, current_ref})
    assert %{timer: {_, new_ref}} = :sys.get_state(pid)
    refute new_ref == current_ref
  end
end
