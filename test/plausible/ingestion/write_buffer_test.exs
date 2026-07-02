defmodule Plausible.Ingestion.WriteBufferTest do
  use ExUnit.Case, async: true

  alias Plausible.Ingestion.WriteBuffer

  @opts WriteBuffer.compile_time_prepare(Plausible.ClickhouseEventV2)

  test "keeps running when a linked process exits while trapping exits" do
    opts =
      @opts
      |> Map.take([:header, :insert_sql, :insert_opts])
      |> Map.to_list()
      |> Keyword.put(:name, :"write_buffer_exit_#{System.unique_integer([:positive])}")
      # large interval so the empty buffer never flushes to ClickHouse during the test
      |> Keyword.put(:flush_interval_ms, 60_000)

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
    Process.exit(child, :shutdown)
    assert_receive {:DOWN, ^ref, :process, ^child, _}, 1_000

    assert Process.alive?(pid)
    assert WriteBuffer.flush(opts[:name]) == :ok
  end
end
