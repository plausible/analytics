defmodule Plausible.Repo.Migrations.AdjustUsersSsoConstraints do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      alter table(:users) do
        add :sso_domain_id, references(:sso_domains, on_delete: :nothing), null: true

        modify :sso_integration_id, references(:sso_integrations, on_delete: :nothing),
          from: references(:sso_integrations, on_delete: :nilify_all),
          null: true
      end

      create index(:users, [:sso_domain_id])
    end
  end
end
