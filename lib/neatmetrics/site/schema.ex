defmodule Neatmetrics.Site do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sites" do
    field :domain, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:domain])
    |> validate_required([:domain])
  end
end
