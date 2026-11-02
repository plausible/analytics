defmodule Plausible.Repo.Migrations.AddFunnelTypeToFunnels do
  use Ecto.Migration

  def change do
    alter table(:funnels) do
      add :funnel_type, :string, null: false, default: "sequential"
    end
  end
end
