defmodule Plausible.Teams.Invitation do
  @moduledoc """
  Team invitation schema
  """

  use Ecto.Schema

  schema "team_invitations" do
    field :invitation_id, :string
    field :email, :string
    field :role, Ecto.Enum, values: [:guest, :viewer, :editor, :admin, :owner]

    belongs_to :inviter, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    has_many :guest_invitations, Plausible.Teams.GuestInvitation, foreign_key: :team_invitation_id

    timestamps()
  end
end
