defmodule Plausible.Site do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sites" do
    field :domain, :string
    field :timezone, :string

    timestamps()
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:domain, :timezone])
    |> validate_required([:domain, :timezone])
    |> unique_constraint(:domain)
  end
end
