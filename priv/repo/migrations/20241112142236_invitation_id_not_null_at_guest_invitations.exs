defmodule Plausible.Repo.Migrations.InvitationIdNotNullAtGuestInvitations do
  use Ecto.Migration

  def change do
    alter table(:guest_invitations) do
      modify :invitation_id, :string, null: false
    end
  end
end
