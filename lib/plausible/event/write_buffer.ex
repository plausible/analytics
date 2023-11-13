defmodule Plausible.Event.WriteBuffer do
  @moduledoc false

  fields = Plausible.ClickhouseEventV2.__schema__(:fields)

  types =
    Enum.map(fields, fn field ->
      type =
        Plausible.ClickhouseEventV2.__schema__(:type, field) || raise "missing type for #{field}"

      type
      |> Ecto.Type.type()
      |> Ecto.Adapters.ClickHouse.Schema.remap_type(Plausible.ClickhouseEventV2, field)
    end)

  encoding_types = Ch.RowBinary.encoding_types(types)

  header =
    fields
    |> Enum.map(&to_string/1)
    |> Ch.RowBinary.encode_names_and_types(types)
    |> IO.iodata_to_binary()

  insert_sql =
    "INSERT INTO #{Plausible.ClickhouseEventV2.__schema__(:source)} FORMAT RowBinaryWithNamesAndTypes"

  defp merge_opts(opts) do
    Keyword.merge(opts, name: __MODULE__, header: unquote(header), sql: unquote(insert_sql))
  end

  def child_spec(opts) do
    Plausible.Ingestion.WriteBuffer.child_spec(merge_opts(opts))
  end

  @spec insert(event) :: {:ok, event} when event: %Plausible.ClickhouseEventV2{}
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
