defmodule Plausible.Session.WriteBuffer do
  @moduledoc false

  %{
    header: header,
    insert_sql: insert_sql,
    insert_opts: insert_opts,
    fields: fields,
    encoding_types: encoding_types
  } =
    Plausible.Ingestion.WriteBuffer.compile_time_prepare(Plausible.ClickhouseSessionV2)

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

  def insert(sessions) do
    row_binary =
      sessions
      |> Enum.map(fn %{is_bounce: is_bounce} = session ->
        {:ok, is_bounce} = Plausible.ClickhouseSessionV2.BoolUInt8.dump(is_bounce)
        session = %{session | is_bounce: is_bounce}
        Enum.map(unquote(fields), fn field -> Map.fetch!(session, field) end)
      end)
      |> Ch.RowBinary._encode_rows(unquote(encoding_types))
      |> IO.iodata_to_binary()

    :ok = Plausible.Ingestion.WriteBuffer.insert(__MODULE__, row_binary)
    {:ok, sessions}
  end

  def flush do
    Plausible.Ingestion.WriteBuffer.flush(__MODULE__)
  end
end
