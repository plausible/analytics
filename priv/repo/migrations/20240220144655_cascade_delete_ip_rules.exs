defmodule Plausible.Repo.Migrations.CascadeDeleteIpRules do
  use Ecto.Migration

  def up do
    drop_if_exists constraint(:shield_rules_ip, "shield_rules_ip_site_id_fkey")

    alter table(:shield_rules_ip) do
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end
  end

  def down do
    drop_if_exists constraint(:shield_rules_ip, "shield_rules_ip_site_id_fkey")

    alter table(:shield_rules_ip) do
      modify :site_id, references(:sites), null: false
    end
  end
end
