defmodule Plausible.Repo.Migrations.AddSiteIdToEvents do
  use Ecto.Migration

  def up do
    alter table(:events) do
      add :site_id, :text
    end

    alter table(:sessions) do
      add :site_id, :text
    end

    execute "UPDATE events set site_id=hostname"
    execute "UPDATE sessions set site_id=hostname"

    alter table(:events) do
      modify :site_id, :text, null: false
    end

    alter table(:sessions) do
      modify :site_id, :text, null: false
    end

    create index(:events, :site_id)
    create index(:sessions, :site_id)
  end

  def down do
    alter table(:events) do
      remove :site_id
    end

    alter table(:sessions) do
      remove :site_id
    end
  end
end
