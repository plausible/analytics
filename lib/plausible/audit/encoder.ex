defmodule Plausible.Audit.EncoderError do
  defexception [:message]
end

defprotocol Plausible.Audit.Encoder do
  def encode(x)
end

defimpl Plausible.Audit.Encoder, for: Ecto.Changeset do
  def encode(changeset) do
    changes =
      Enum.reduce(changeset.changes, %{}, fn {k, v}, acc ->
        Map.put(acc, k, Plausible.Audit.Encoder.encode(v))
      end)

    data = Plausible.Audit.Encoder.encode(changeset.data)

    case {map_size(data), map_size(changes)} do
      {n, 0} when n > 0 ->
        data

      {0, n} when n > 0 ->
        changes

      {0, 0} ->
        %{}

      _ ->
        %{before: data, after: changes}
    end
  end
end

defimpl Plausible.Audit.Encoder, for: Map do
  def encode(x) do
    {allow_not_loaded, data} = Map.pop(x, :__allow_not_loaded__)

    Enum.reduce(data, %{}, fn
      {k, %Ecto.Association.NotLoaded{}}, acc ->
        if k in allow_not_loaded do
          acc
        else
          raise Plausible.Audit.EncoderError,
            message:
              "#{k} association not loaded. Either preload, exclude or mark it as :allow_not_loaded in #{__MODULE__} options"
        end

      {k, v}, acc ->
        Map.put(acc, k, Plausible.Audit.Encoder.encode(v))
    end)
  end
end

defimpl Plausible.Audit.Encoder, for: [Integer, BitString, Float] do
  def encode(x), do: x
end

defimpl Plausible.Audit.Encoder, for: [DateTime, Date, NaiveDateTime, Time] do
  def encode(x), do: to_string(x)
end

defimpl Plausible.Audit.Encoder, for: [Atom] do
  def encode(nil), do: nil
  def encode(true), do: true
  def encode(false), do: false
  def encode(x), do: Atom.to_string(x)
end

defimpl Plausible.Audit.Encoder, for: List do
  def encode(x), do: Enum.map(x, &Plausible.Audit.Encoder.encode/1)
end

defimpl Plausible.Audit.Encoder, for: Any do
  defmacro __deriving__(module, struct, options) do
    deriving(module, struct, options)
  end

  def deriving(module, _struct, options) do
    only = options[:only]
    except = options[:except]
    allow_not_loaded = options[:allow_not_loaded] || []

    extractor =
      cond do
        only ->
          quote(
            do:
              struct
              |> Map.take(unquote(only))
              |> Map.put(:__allow_not_loaded__, unquote(allow_not_loaded))
          )

        except ->
          except = [:__struct__ | except]

          quote(
            do:
              struct
              |> Map.drop(
                unquote(except)
                |> Map.put(:__allow_not_loaded__, unquote(allow_not_loaded))
              )
          )

        true ->
          quote(do: :maps.remove(:__struct__, struct))
      end

    quote do
      defimpl Plausible.Audit.Encoder, for: unquote(module) do
        def encode(struct) do
          Plausible.Audit.Encoder.encode(unquote(extractor))
        end
      end
    end
  end

  def encode(_), do: raise("Implement me")
end
