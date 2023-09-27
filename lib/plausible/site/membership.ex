defmodule Plausible.Site.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "site_memberships" do
    field :role, Ecto.Enum, values: [:owner, :admin, :viewer]
    belongs_to :site, Plausible.Site
    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  def new(site, user) do
    %__MODULE__{}
    |> change()
    |> put_assoc(:site, site)
    |> put_assoc(:user, user)
  end

  def set_role(changeset, role) do
    changeset
    |> cast(%{role: role}, [:role])
  end
end
