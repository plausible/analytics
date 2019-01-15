defmodule Neatmetrics.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string

    has_many :site_memberships, Neatmetrics.Site.Membership
    has_many :sites, through: [:site_memberships, :site]

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
  end
end
