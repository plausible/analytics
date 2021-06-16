defmodule Plausible.Repo.Migrations.AddInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations) do
      add :email, :string, null: false
      add :site_id, references(:sites), null: false
      add :inviter_id, references(:users), null: false
      add :role, :site_membership_role, null: false
      add :invitation_id, :string

      timestamps()
    end

    create unique_index(:invitations, [:site_id, :email])
    create unique_index(:invitations, :invitation_id)
  end
end
