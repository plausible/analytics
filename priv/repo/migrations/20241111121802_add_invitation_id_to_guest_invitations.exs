defmodule Plausible.Repo.Migrations.AddInvitationIdToGuestInvitations do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    alter table(:guest_invitations) do
      add :invitation_id, :string
    end

    create unique_index(:guest_invitations, [:invitation_id])
  end
end
