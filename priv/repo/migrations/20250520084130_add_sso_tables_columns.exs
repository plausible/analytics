defmodule Plausible.Repo.Migrations.AddSsoTablesColumns do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      create table(:sso_integrations) do
        add :identifier, :binary, null: false
        add(:config, :jsonb, null: false)

        add :team_id, references(:teams, on_delete: :delete_all), null: false

        timestamps()
      end

      # NOTE: Currently we enforce only a single integration per team at
      # a time. If we are going to support more than one integration
      # per team in the future, this index will be replaced with a
      # non-unique one.
      create unique_index(:sso_integrations, [:team_id])

      create unique_index(:sso_integrations, [:identifier])

      create table(:sso_domains) do
        add :identifier, :binary, null: false
        add :domain, :text, null: false
        add :validated_via, :string, null: true
        add :last_validated_at, :naive_datetime, null: true
        add :status, :string, null: false

        add :sso_integration_id, references(:sso_integrations, on_delete: :delete_all),
          null: false

        timestamps()
      end

      create unique_index(:sso_domains, [:identifier])
      create unique_index(:sso_domains, [:domain])
      create index(:sso_domains, [:sso_integration_id])

      alter table(:teams) do
        add :policy, :jsonb, null: false, default: "{}"
      end

      alter table(:users) do
        add :type, :string, null: false, default: "standard"
        add :sso_identity_id, :string, null: true
        add :last_sso_login, :naive_datetime, null: true

        add :sso_integration_id, references(:sso_integrations, on_delete: :nilify_all), null: true
      end

      create index(:users, [:sso_integration_id])
    end
  end
end
