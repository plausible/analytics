defmodule Plausible.Site.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "site_memberships" do
    field :role, Ecto.Enum, values: [:owner, :admin, :viewer]
    belongs_to :site, Plausible.Site
    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:user_id, :site_id, :role])
    |> validate_required([:user_id, :site_id])
  end
end
