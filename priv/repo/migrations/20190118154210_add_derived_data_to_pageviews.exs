defmodule Plausible.Repo.Migrations.AddDerivedDataToPageviews do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:pageviews) do
      add :device_type, :string
      add :browser, :string
      add :operating_system, :string
      add :referrer_source, :string
      add :screen_size, :string
    end
  end
end
