defmodule Plausible.Site.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "site_memberships" do
    belongs_to :site, Plausible.Site
    belongs_to :user, Plausible.Auth.User
    field :role, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:user_id, :site_id])
    |> validate_required([:user_id, :site_id])
  end
end
