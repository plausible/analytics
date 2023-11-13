defmodule Plausible.Session.WriteBuffer do
  @moduledoc false

  fields = Plausible.ClickhouseSessionV2.__schema__(:fields)

  types =
    Enum.map(fields, fn field ->
      type =
        Plausible.ClickhouseSessionV2.__schema__(:type, field) ||
          raise "missing type for #{field}"

      type
      |> Ecto.Type.type()
      |> Ecto.Adapters.ClickHouse.Schema.remap_type(Plausible.ClickhouseSessionV2, field)
    end)

  encoding_types = Ch.RowBinary.encoding_types(types)

  header =
    fields
    |> Enum.map(&to_string/1)
    |> Ch.RowBinary.encode_names_and_types(types)
    |> IO.iodata_to_binary()

  insert_sql =
    "INSERT INTO #{Plausible.ClickhouseSessionV2.__schema__(:source)} FORMAT RowBinaryWithNamesAndTypes"

  defp merge_opts(opts) do
    Keyword.merge(opts, name: __MODULE__, header: unquote(header), sql: unquote(insert_sql))
  end

  def child_spec(opts) do
    Plausible.Ingestion.WriteBuffer.child_spec(merge_opts(opts))
  end

  @spec insert(sessions) :: {:ok, sessions} when sessions: [%Plausible.ClickhouseSessionV2{}]
  def insert(sessions) do
    row_binary =
      sessions
      |> Enum.map(fn %{is_bounce: is_bounce} = session ->
        is_bounce =
          case is_bounce do
            true -> 1
            false -> 0
            other -> other
          end

        %{session | is_bounce: is_bounce}
      end)
      |> Enum.map(fn session ->
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
