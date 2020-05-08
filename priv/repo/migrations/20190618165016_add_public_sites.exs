defmodule Plausible.Repo.Migrations.AddPublicSites do
  use Ecto.Migration
  @host PlausibleWeb.Endpoint.host()

  def change do
    alter table(:sites) do
      add :public, :boolean, null: false, default: false
    end

    execute "update sites set public=true where domain='#{@host}'"
  end
end
