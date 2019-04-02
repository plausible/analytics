defmodule Plausible.Repo.Migrations.RemoveDeviceTypeFromPageviews do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      remove :device_type
    end
  end
end
