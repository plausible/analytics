defmodule Plausible.Ingestion.Persistor.Remote.Serializer do
  @moduledoc false

  alias Plausible.ClickhouseEventV2
  alias Plausible.ClickhouseSessionV2

  defmodule Builder do
    @moduledoc false

    def deserializer(:string), do: quote(do: &Function.identity/1)
    def deserializer({:array, :string}), do: quote(do: &Function.identity/1)
    def deserializer(:boolean), do: quote(do: &Function.identity/1)
    def deserializer(ClickhouseSessionV2.BoolUInt8), do: quote(do: &Function.identity/1)
    def deserializer(:naive_datetime), do: quote(do: &NaiveDateTime.from_iso8601!/1)
    def deserializer({:parameterized, {Ch, {_, :string}}}), do: quote(do: &Function.identity/1)

    def deserializer({:parameterized, {Ch, {:fixed_string, _}}}),
      do: quote(do: &Function.identity/1)

    def deserializer({:parameterized, {Ch, {_, {:fixed_string, _}}}}),
      do: &Function.identity/1

    def deserializer({:parameterized, {Ch, :i32}}), do: quote(do: &Function.identity/1)
    def deserializer({:parameterized, {Ch, :i8}}), do: quote(do: &Function.identity/1)
    def deserializer({:parameterized, {Ch, :u64}}), do: quote(do: &Function.identity/1)
    def deserializer({:parameterized, {Ch, :u32}}), do: quote(do: &Function.identity/1)
    def deserializer({:parameterized, {Ch, :u8}}), do: quote(do: &Function.identity/1)
    def deserializer({:parameterized, {Ch, {_, {:decimal64, _}}}}), do: quote(do: &Decimal.new/1)

    def deserializer(type) do
      raise "unsupported deserialization type: #{inspect(type)}"
    end

    def serializer(:string), do: quote(do: &Function.identity/1)
    def serializer({:array, :string}), do: quote(do: &Function.identity/1)
    def serializer(:boolean), do: quote(do: &Function.identity/1)
    def serializer(ClickhouseSessionV2.BoolUInt8), do: quote(do: &Function.identity/1)
    def serializer(:naive_datetime), do: quote(do: &NaiveDateTime.to_iso8601/1)
    def serializer({:parameterized, {Ch, {_, :string}}}), do: quote(do: &Function.identity/1)

    def serializer({:parameterized, {Ch, {:fixed_string, _}}}),
      do: quote(do: &Function.identity/1)

    def serializer({:parameterized, {Ch, {_, {:fixed_string, _}}}}),
      do: &Function.identity/1

    def serializer({:parameterized, {Ch, :i32}}), do: quote(do: &Function.identity/1)
    def serializer({:parameterized, {Ch, :i8}}), do: quote(do: &Function.identity/1)
    def serializer({:parameterized, {Ch, :u64}}), do: quote(do: &Function.identity/1)
    def serializer({:parameterized, {Ch, :u32}}), do: quote(do: &Function.identity/1)
    def serializer({:parameterized, {Ch, :u8}}), do: quote(do: &Function.identity/1)
    def serializer({:parameterized, {Ch, {_, {:decimal64, _}}}}), do: quote(do: &to_string/1)

    def serializer(type) do
      raise "unsupported serialization type: #{inspect(type)}"
    end
  end

  @event_fields ClickhouseEventV2.__schema__(:fields) ++
                  ClickhouseEventV2.__schema__(:virtual_fields)
  @event_string_fields Enum.map(@event_fields, &to_string/1)
  @event_mappings Map.new(@event_fields, fn field -> {to_string(field), field} end)

  @spec encode(ClickhouseEventV2.t(), map()) :: binary()
  def encode(event, session_attrs) do
    event_data =
      event
      |> Map.from_struct()
      |> Map.delete(:__meta__)
      |> Enum.reject(fn {_key, val} -> is_nil(val) end)
      |> Map.new(fn {key, val} ->
        {key, serialize_field(:event, key, val)}
      end)

    session_data =
      session_attrs
      |> Enum.reject(fn {_key, val} -> is_nil(val) end)
      |> Map.new(fn {key, val} ->
        {key, serialize_field(:session, key, val)}
      end)

    Jason.encode!(%{
      event: event_data,
      session: session_data
    })
  end

  @spec decode(binary()) ::
          {:ok, ClickhouseEventV2.t()} | {:error, :invalid_payload | :malformed_payload}
  def decode(payload) do
    case Jason.decode(payload) do
      {:ok, data} ->
        event_attrs =
          data
          |> Map.take(@event_string_fields)
          |> Map.new(fn {key, val} ->
            atom_key = Map.fetch!(@event_mappings, key)
            {atom_key, deserialize_field(:event, atom_key, val)}
          end)

        {:ok, struct(Plausible.ClickhouseEventV2, event_attrs)}

      _ ->
        {:error, :malformed_payload}
    end
  catch
    _, _ ->
      {:error, :invalid_payload}
  end

  for {fields_key, type_key} <- [{:fields, :type}, {:virtual_fields, :virtual_type}] do
    for {name, schema} <- [{:event, ClickhouseEventV2}, {:session, ClickhouseSessionV2}] do
      for field <- schema.__schema__(fields_key) do
        type = schema.__schema__(type_key, field)
        fun = Builder.serializer(type)

        defp serialize_field(unquote(name), unquote(field), value) do
          unquote(fun).(value)
        end
      end
    end
  end

  for {fields_key, type_key} <- [{:fields, :type}, {:virtual_fields, :virtual_type}] do
    for field <- ClickhouseEventV2.__schema__(fields_key) do
      type = ClickhouseEventV2.__schema__(type_key, field)
      fun = Builder.deserializer(type)

      defp deserialize_field(:event, unquote(field), value) do
        unquote(fun).(value)
      end
    end
  end
end
