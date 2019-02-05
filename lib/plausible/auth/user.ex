defmodule Plausible.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :last_seen, :naive_datetime

    has_many :site_memberships, Plausible.Site.Membership
    has_many :sites, through: [:site_memberships, :site]

    timestamps()
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email, :name])
    |> unique_constraint(:email)
  end
end
