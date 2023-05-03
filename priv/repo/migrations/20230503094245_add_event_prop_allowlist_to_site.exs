defmodule Plausible.Repo.Migrations.AddEventPropAllowlistToSite do
  use Ecto.Migration

  def change do
    alter table("sites") do
      add :allowed_event_props, {:array, :string}, null: false, default: []
    end
  end
end
