defmodule Plausible.Repo.Migrations.InstallCarbonite do
  use Ecto.Migration

  def up do
    Carbonite.Migrations.up(1..12)
    Carbonite.Migrations.create_trigger("users")

    Carbonite.Migrations.put_trigger_config(:users, :excluded_columns, [
      "password_hash",
      "last_seen",
      "theme",
      "totp_secret",
      "totp_token",
      "totp_last_used_at",
      "last_team_identifier",
      "updated_at",
      "inserted_at"
    ])

    Carbonite.Migrations.create_trigger("sso_integrations")
    Carbonite.Migrations.create_trigger("sso_domains")
  end

  def down do
    Carbonite.Migrations.drop_trigger("users")
    Carbonite.Migrations.down(12..1)
  end
end
