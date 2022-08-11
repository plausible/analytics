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
    |> validate_inclusion(:role, valid_roles(schema.role))
  end

  def override_role(schema, role) do
    schema
    |> change(%{role: role})
    |> validate_required([:user_id, :site_id, :role])
  end

  defp valid_roles(_prev_role = nil), do: [:owner, :admin, :viewer]
  defp valid_roles(:owner), do: [:owner, :admin, :viewer]
  defp valid_roles(:admin), do: [:admin, :viewer]
  defp valid_roles(:viewer), do: [:viewer]
end
