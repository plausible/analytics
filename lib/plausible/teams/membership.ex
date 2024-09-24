defmodule Plausible.Teams.Membership do
  @moduledoc """
  Team membership schema
  """

  use Ecto.Schema

  schema "team_memberships" do
    field :role, Ecto.Enum, values: [:guest, :viewer, :editor, :admin, :owner]

    belongs_to :user, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    has_many :guest_memberships, Plausible.Teams.GuestMembership, foreign_key: :team_membership_id

    timestamps()
  end
end
