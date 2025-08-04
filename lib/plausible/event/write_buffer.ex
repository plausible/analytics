defmodule Plausible.Event.WriteBuffer do
  @moduledoc false

  %{
    header: header,
    insert_sql: insert_sql,
    insert_opts: insert_opts,
    fields: fields,
    encoding_types: encoding_types
  } =
    Plausible.Ingestion.WriteBuffer.compile_time_prepare(Plausible.ClickhouseEventV2)

  def child_spec(opts) do
    opts =
      Keyword.merge(opts,
        name: __MODULE__,
        header: unquote(header),
        insert_sql: unquote(insert_sql),
        insert_opts: unquote(insert_opts)
      )

    Plausible.Ingestion.WriteBuffer.child_spec(opts)
  end

  def insert(event) do
    row_binary =
      [Enum.map(unquote(fields), fn field -> Map.fetch!(event, field) end)]
      |> Ch.RowBinary._encode_rows(unquote(encoding_types))
      |> IO.iodata_to_binary()

    :ok = Plausible.Ingestion.WriteBuffer.insert(__MODULE__, row_binary)
    {:ok, event}
  end

  def flush do
    Plausible.Ingestion.WriteBuffer.flush(__MODULE__)
  end

  def lock(timeout) do
    Plausible.Ingestion.WriteBuffer.lock(__MODULE__, timeout)
  end

  def unlock() do
    Plausible.Ingestion.WriteBuffer.unlock(__MODULE__)
  end
end
