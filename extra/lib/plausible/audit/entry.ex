defmodule Plausible.Audit.Entry do
  @moduledoc """
  Persistent Audit Entry schema 
  """

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

  @primary_key {:id, :binary_id, autogenerate: true}
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
    field :actor_type, Ecto.Enum, default: :system, values: [:system, :user]
  end

  def changeset(name, params) do
    context = get_context()

    params =
      Map.merge(
        %{
          team_id: context[:current_team] && context.current_team.id,
          user_id: context[:current_user] && context.current_user.id,
          actor_type: if(context[:current_user], do: "user", else: "system")
        },
        params
      )

    %__MODULE__{name: name}
    |> cast(params, [:entity, :entity_id, :meta, :user_id, :team_id, :actor_type])
    |> validate_required([:name, :entity, :entity_id, :actor_type])
    |> put_change(:datetime, NaiveDateTime.utc_now())
  end

  def new(name, %{__struct__: struct, id: id}, params \\ %{}) do
    changeset(name, Map.merge(%{entity: to_str(struct), entity_id: to_str(id)}, params))
  end

  def include_change(audit_entry, %Ecto.Changeset{} = related_changeset) do
    audit_entry
    |> change()
    |> put_change(:change, Plausible.Audit.encode(related_changeset))
  end

  def include_change(audit_entry, %{__struct__: _} = struct) do
    # inserts hardly ever preload associations, so raising on not loaded is not useful
    audit_entry
    |> change()
    |> put_change(:change, Plausible.Audit.encode(struct, raise_on_not_loaded?: false))
  end

  def persist!(entry) do
    Plausible.Repo.insert!(entry)
  end

  defp get_context() do
    case :logger.get_process_metadata() do
      %{:__audit__ => audit_context} -> audit_context
      %{} -> %{}
      :undefined -> %{}
    end
  end

  def set_context(kv) when is_map(kv) do
    :logger.update_process_metadata(%{:__audit__ => kv})
  end

  defp to_str(x) when is_binary(x), do: x
  defp to_str(x) when is_atom(x), do: inspect(x)
  defp to_str(x), do: to_string(x)
end
