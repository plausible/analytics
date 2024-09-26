defmodule Plausible.Teams.Invitation do
  @moduledoc """
  Team invitation schema
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "team_invitations" do
    field :invitation_id, :string
    field :email, :string
    field :role, Ecto.Enum, values: [:guest, :viewer, :editor, :admin, :owner]

    belongs_to :inviter, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    has_many :guest_invitations, Plausible.Teams.GuestInvitation, foreign_key: :team_invitation_id

    timestamps()
  end

  def changeset(team, opts) do
    email = Keyword.fetch!(opts, :email)
    role = Keyword.fetch!(opts, :role)
    inviter = Keyword.fetch!(opts, :inviter)

    %__MODULE__{invitation_id: Nanoid.generate()}
    |> cast(%{email: email, role: role}, [:email, :role])
    |> validate_required([:email, :role])
    |> put_assoc(:team, team)
    |> put_assoc(:inviter, inviter)
  end
end
