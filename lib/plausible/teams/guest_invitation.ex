defmodule Plausible.Teams.GuestInvitation do
  @moduledoc """
  Guest invitation schema
  """

  use Ecto.Schema

  schema "guest_invitations" do
    field :role, Ecto.Enum, values: [:viewer, :editor]

    belongs_to :site, Plausible.Site
    belongs_to :team_invitation, Plausible.Teams.Invitation

    timestamps()
  end
end
