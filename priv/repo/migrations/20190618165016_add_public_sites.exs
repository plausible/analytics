defmodule Plausible.Repo.Migrations.AddPublicSites do
  use Ecto.Migration

  def change do
    host = Application.get_env(:plausible, :url, :host)

    alter table(:sites) do
      add :public, :boolean, null: false, default: false
    end

    execute "update sites set public=true where domain='#{host}'"
  end
end
