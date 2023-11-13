defmodule Plausible.Event.WriteBuffer do
  @moduledoc false

  %{header: header, sql: sql, fields: fields, encoding_types: encoding_types} =
    Plausible.Ingestion.WriteBuffer.compile_time_prepare(Plausible.ClickhouseEventV2)

  def child_spec(opts) do
    opts = Keyword.merge(opts, name: __MODULE__, header: unquote(header), sql: unquote(sql))
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
end
