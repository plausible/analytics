defmodule Plausible.ApiRequestLog.WriteBuffer do
  @moduledoc false

  %{
    header: header,
    insert_sql: insert_sql,
    insert_opts: insert_opts,
    fields: fields,
    encoding_types: encoding_types
  } =
    Plausible.Ingestion.WriteBuffer.compile_time_prepare(Plausible.ApiRequestLog.Entry)

  def child_spec(opts) do
    opts =
      Keyword.merge(opts,
        name: __MODULE__,
        flush_interval_ms: :timer.seconds(60),
        header: unquote(header),
        insert_sql: unquote(insert_sql),
        insert_opts: unquote(insert_opts)
      )

    Plausible.Ingestion.WriteBuffer.child_spec(opts)
  end

  def insert(entry) do
    row_binary =
      [Enum.map(unquote(fields), fn field -> Map.fetch!(entry, field) end)]
      |> Ch.RowBinary._encode_rows(unquote(encoding_types))
      |> IO.iodata_to_binary()

    :ok = Plausible.Ingestion.WriteBuffer.insert(__MODULE__, row_binary)
  end

  def flush do
    Plausible.Ingestion.WriteBuffer.flush(__MODULE__)
  end
end
