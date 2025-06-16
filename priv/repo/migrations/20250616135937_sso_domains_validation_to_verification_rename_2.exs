defmodule Plausible.Repo.Migrations.SsoDomainsValidationToVerificationRename2 do
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      alter table(:sso_domains) do
        remove :validated_via
        remove :last_validated_at
      end
    end
  end
end
