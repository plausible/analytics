defmodule Plausible.Repo.Migrations.AddIpBlockListTable do
  use Ecto.Migration

  def change do
    create table(:shield_rules_ip) do
      add :site_id, references(:sites), null: false
      add :ip_address, :inet
      add :action, :string, default: "deny", null: false
      add :description, :string
      timestamps()
    end

    create unique_index(:shield_rules_ip, [:site_id, :ip_address])
  end
end
