defmodule Plausible.Repo.Migrations.SsoDomainsValidationToVerificationRename do
  use Ecto.Migration

  def change do
    rename table(:sso_domains), :validated_via, to: :verified_via
    rename table(:sso_domains), :last_validated_at, to: :last_verified_at
  end
end
