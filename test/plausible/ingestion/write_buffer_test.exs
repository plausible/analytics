defmodule Plausible.Ingestion.WriteBufferTest do
  use ExUnit.Case, async: true

  alias Plausible.Ingestion.WriteBuffer

  @opts WriteBuffer.compile_time_prepare(Plausible.ClickhouseEventV2)

  test "survives :EXIT messages from linked processes while trapping exits" do
    opts =
      @opts
      |> Map.take([:header, :insert_sql, :insert_opts])
      |> Map.to_list()
      |> Keyword.put(:name, :"write_buffer_exit_#{System.unique_integer([:positive])}")
      # large buffer so the empty buffer never flushes to ClickHouse during the test
      |> Keyword.put(:flush_interval_ms, 60_000)

    {:ok, pid} = WriteBuffer.start_link(opts)

    send(pid, {:EXIT, self(), :normal})

    # process is still alive and responsive after the :EXIT message
    assert Process.alive?(pid)
    assert WriteBuffer.flush(opts[:name]) == :ok
  end
end
