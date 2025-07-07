defmodule Plausible.Audit do
  alias Plausible.Repo
  import Ecto.Query

  defmodule Entry do
    use Ecto.Schema

    @type t :: %__MODULE__{
            name: String.t(),
            entity: String.t(),
            entity_id: String.t(),
            meta: map(),
            changed_from: map(),
            changed_to: map(),
            user_id: integer(),
            team_id: integer(),
            datetime: NaiveDateTime.t()
          }

    schema "audit_entries" do
      field :name, :string
      field :entity, :string
      field :entity_id, :string
      field :meta, :map
      field :changed_from, :map, default: %{}
      field :changed_to, :map, default: %{}
      field :user_id, :integer
      field :team_id, :integer
      field :datetime, :naive_datetime_usec
    end
  end

  def new(name) do
    new(name, [])
  end

  def new(name, attrs) when is_list(attrs) do
    context = get_context()

    attrs =
      attrs
      |> Keyword.put(:datetime, NaiveDateTime.utc_now())
      |> Keyword.put(:name, name)
      |> Keyword.put(:user_id, Map.get(context, :current_user_id, attrs[:user_id]))
      |> Keyword.put(:team_id, Map.get(context, :current_team_id, attrs[:team_id]))
      |> Keyword.update(:entity, nil, fn
        existing when is_binary(existing) -> existing
        existing when is_atom(existing) -> inspect(existing)
      end)

    struct(Entry, attrs)
  end

  def new(name, %struct{} = conn_or_socket, attrs \\ [])
      when is_list(attrs) and is_map(conn_or_socket) and
             struct in [Plug.Conn, Phoenix.LiveView.Socket] do
    team_id =
      case conn_or_socket.assigns[:current_team] do
        %{id: id} -> id
        _ -> nil
      end

    user_id =
      case conn_or_socket.assigns[:current_user] do
        %{id: id} -> id
        _ -> nil
      end

    new(name, Keyword.merge(attrs, team_id: team_id, user_id: user_id))
  end

  def track_changes(%Entry{} = entry, %Ecto.Changeset{} = changeset) do
    schema = inspect(changeset.data.__struct__)
    original = Map.from_struct(changeset.data)

    changes = changeset.changes
    changed_fields = changes |> Map.keys() |> Enum.reject(&secret?/1)

    changed_from =
      if changeset.data.id do
        changed_fields
        |> Enum.map(fn field ->
          {field, clean(Map.get(original, field))}
        end)
        |> Enum.into(%{})
      else
        nil
      end

    changed_to =
      changes
      |> Enum.reject(fn {field, _} -> secret?(field) end)
      |> Enum.map(fn {field, value} ->
        {field, clean(value)}
      end)
      |> Enum.into(%{})

    struct(entry,
      entity: schema,
      entity_id: to_string(original.id),
      changed_from: changed_from,
      changed_to: changed_to
    )
  end

  def persist(%Entry{} = entry) do
    Repo.insert!(entry)
  end

  def list_by(attrs) do
    attrs =
      attrs
      |> Keyword.update(:entity, nil, fn
        existing when is_binary(existing) -> existing
        existing when is_atom(existing) -> inspect(existing)
      end)
      |> Keyword.update(:entity_id, nil, fn
        existing when is_binary(existing) -> existing
        existing -> to_string(existing)
      end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    Repo.all(from e in Entry, where: ^attrs, order_by: [asc: e.id])
  end

  defp get_context() do
    case :logger.get_process_metadata() do
      %{:__audit__ => audit_context} -> audit_context
      %{} -> %{}
      :undefined -> %{}
    end
  end

  def set_context(kv) do
    :logger.update_process_metadata(%{
      :__audit__ => Map.new(kv)
    })
  end

  def clean(%Ecto.Changeset{} = changeset) do
    %{id: changeset.data.id}
  end

  def clean(%date{} = d) when date in [DateTime, NaiveDateTime, Date] do
    to_string(d)
  end

  def clean(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([
      :__meta__,
      :__struct__,
      :updated_at,
      :inserted_at,
      :__cardinality__,
      :__field__,
      :__owner__
    ])
    |> Enum.reduce(%{}, fn
      {_key, %Ecto.Association.NotLoaded{}}, acc ->
        acc

      {key, %date{} = d}, acc when date in [DateTime, NaiveDateTime, Date] ->
        Map.put(acc, key, to_string(d))

      {key, value}, acc when is_struct(value) ->
        Map.put(acc, key, clean(value))

      {key, value}, acc when is_list(value) ->
        Map.put(acc, key, Enum.map(value, &clean/1))

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  def clean(other), do: other

  defp secret?(f) do
    f = to_string(f)
    String.contains?(f, "password") or String.contains?(f, "secret")
  end
end
