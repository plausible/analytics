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
end
