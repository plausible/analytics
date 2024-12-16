defmodule Plausible.Teams.GuestMembership do
  @moduledoc """
  Guest membership schema
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "guest_memberships" do
    field :role, Ecto.Enum, values: [:viewer, :editor]

    belongs_to :team_membership, Plausible.Teams.Membership
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(team_membership, site, role) do
    %__MODULE__{}
    |> change()
    |> put_change(:role, role)
    |> put_assoc(:team_membership, team_membership)
    |> put_assoc(:site, site)
  end
end
