defmodule Plausible.Repo.Migrations.SsoDomainsValidationToVerificationRename do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      alter table(:sso_domains) do
        add :verified_via, :string, null: true
        add :last_verified_at, :naive_datetime, null: true
      end
    end
  end
end
