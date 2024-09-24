defmodule Plausible.Teams.GuestMembership do
  @moduledoc """
  Guest membership schema
  """

  use Ecto.Schema

  schema "guest_memberships" do
    field :role, Ecto.Enum, values: [:viewer, :editor]

    belongs_to :team_membership, Plausible.Teams.Membership
    belongs_to :site, Plausible.Site

    timestamps()
  end
end
