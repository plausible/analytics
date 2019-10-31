defmodule Plausible.Goal do
  use Ecto.Schema
  import Ecto.Changeset

  schema "goals" do
    field :name, :string
    field :domain, :string
    field :event_name, :string
    field :page_path, :string

    timestamps()
  end

  def changeset(goal, attrs \\ %{}) do
    goal
    |> cast(attrs, [:domain, :name, :event_name, :page_path])
    |> validate_required([:domain, :name])
    |> validate_event_name_and_page_path()
  end

  defp validate_event_name_and_page_path(changeset) do
    if present?(changeset, :event_name) || present?(changeset, :page_path) do
      changeset
    else
      changeset
      |> add_error(:event_name, "this field is required")
      |> add_error(:page_path, "this field is required")
    end
  end

  defp present?(changeset, field) do
    value = get_field(changeset, field)
    value && value != ""
  end
end
