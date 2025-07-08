defmodule Plausible.Audit do
  defdelegate encode(term), to: Plausible.Audit.Encoder
  defdelegate set_context(term), to: Plausible.Audit.Entry

  defmodule LiveContext do
    defmacro __using__(_) do
      quote do
        on_mount Plausible.Audit.LiveContext
      end
    end

    def on_mount(:default, _params, _session, socket) do
      if Phoenix.LiveView.connected?(socket) do
        Plausible.Audit.set_context(%{
          current_user: socket.assigns[:current_user],
          current_team: socket.assigns[:current_team]
        })
      end

      {:cont, socket}
    end
  end

  defmodule Entry do
    use Ecto.Schema
    import Ecto.Changeset

    @type t :: %__MODULE__{
            name: String.t(),
            entity: String.t(),
            entity_id: String.t(),
            meta: map(),
            change: map(),
            user_id: integer(),
            team_id: integer(),
            datetime: NaiveDateTime.t()
          }

    schema "audit_entries" do
      field :name, :string
      field :entity, :string
      field :entity_id, :string
      field :meta, :map
      field :change, :map, default: %{}
      # default 0 is still useful in tests?
      field :user_id, :integer, default: 0
      field :team_id, :integer, default: 0
      field :datetime, :naive_datetime_usec
    end

    def changeset(name, params) do
      context =
        get_context()
        |> IO.inspect(label: :context)

      %__MODULE__{name: name}
      |> cast(params, [:name, :entity, :entity_id, :meta])
      |> validate_required([:name, :entity, :entity_id])
      |> put_change(:datetime, NaiveDateTime.utc_now())
      |> put_change(:team_id, context[:current_team] && context.current_team.id)
      |> put_change(:user_id, context[:current_user] && context.current_user.id)
    end

    def new(name, %{__struct__: struct, id: id}, params \\ %{}) do
      changeset(name, Map.merge(%{entity: to_str(struct), entity_id: to_str(id)}, params))
    end

    def name(name, entity, entity_id, params \\ %{})
        when is_binary(entity) and is_binary(entity_id) do
      changeset(name, Map.merge(%{entity: entity, entity_id: entity_id}, params))
    end

    def include_change(audit_entry, %Ecto.Changeset{} = related_changeset) do
      audit_entry
      |> change()
      |> put_change(:change, Plausible.Audit.encode(related_changeset))
    end

    def persist!(entry) do
      Plausible.Repo.insert!(entry)
    end

    defp get_context() do
      case :logger.get_process_metadata() |> IO.inspect(label: :get) do
        %{:__audit__ => audit_context} -> audit_context
        %{} -> %{}
        :undefined -> %{}
      end
    end

    def set_context(kv) when is_map(kv) do
      :logger.update_process_metadata(%{:__audit__ => kv |> IO.inspect(label: :updated_context)})
    end

    defp to_str(x) when is_binary(x), do: x
    defp to_str(x) when is_atom(x), do: inspect(x)
    defp to_str(x), do: to_string(x)
  end
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
          raise "#{k} association not loaded. Either preload, exclude or mark it as :optional in #{__MODULE__} options"
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

defimpl Plausible.Audit.Encoder, for: BitString do
  def encode(x), do: x
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
