defmodule Plausible.Sites.Index.UserPreference do
  @moduledoc """
  User preference persistence schema for the sites index
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Plausible.Sites.Index

  @primary_key false
  embedded_schema do
    field :sort_by, Ecto.Enum, values: Index.sort_by_values(), default: :traffic
    field :sort_direction, Ecto.Enum, values: Index.sort_direction_values(), default: :desc
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:sort_by, :sort_direction])
    |> validate_inclusion(:sort_by, Index.sort_by_values())
    |> validate_inclusion(:sort_direction, Index.sort_direction_values())
  end

  def new(attrs) do
    attrs |> changeset() |> apply_changes()
  end

  def default(), do: %__MODULE__{}
end
