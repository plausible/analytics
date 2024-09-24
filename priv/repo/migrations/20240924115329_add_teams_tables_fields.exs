defmodule Plausible.Repo.Migrations.AddTeamsTablesFields do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :name, :string, null: false
      add :trial_expiry_date, :date
      add :accept_traffic_until, :date
      add :allow_next_upgrade_override, :boolean
      add :grace_period, :jsonb

      timestamps()
    end

    create table(:team_memberships) do
      add :role, :string, null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:team_memberships, [:team_id, :user_id])

    create unique_index(:team_memberships, [:user_id],
             where: "role != 'guest'",
             name: :one_team_per_user
           )

    create index(:team_memberships, [:team_id])
    create index(:team_memberships, [:user_id])

    create table(:guest_memberships) do
      add :role, :string, null: false

      add :team_membership_id, references(:team_memberships, on_delete: :delete_all), null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:guest_memberships, [:team_membership_id, :site_id])
    create index(:guest_memberships, [:team_membership_id])
    create index(:guest_memberships, [:site_id])

    create table(:team_invitations) do
      add :invitation_id, :string, null: false
      add :email, :citext
      add :role, :string, null: false

      add :inviter_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:team_invitations, [:team_id, :email])
    create index(:team_invitations, [:inviter_id])
    create index(:team_invitations, [:team_id])

    create table(:guest_invitations) do
      add :role, :string, null: false

      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :team_invitation_id, references(:team_invitations, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:guest_invitations, [:team_invitation_id, :site_id])
    create index(:guest_invitations, [:site_id])
    create index(:guest_invitations, [:team_invitation_id])

    alter table(:sites) do
      add :team_id, references(:teams, on_delete: :delete_all), null: true
    end

    create index(:sites, [:team_id])

    alter table(:subscriptions) do
      add :team_id, references(:teams, on_delete: :delete_all), null: true
    end

    create index(:subscriptions, [:team_id])

    alter table(:enterprise_plans) do
      add :team_id, references(:teams, on_delete: :delete_all), null: true
    end

    create index(:enterprise_plans, [:team_id])

    alter table(:api_keys) do
      add :team_id, references(:teams, on_delete: :delete_all), null: true
    end

    create index(:api_keys, [:team_id])
  end
end
