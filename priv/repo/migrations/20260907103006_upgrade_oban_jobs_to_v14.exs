defmodule Plausible.Repo.Migrations.UpgradeObanJobsToV14 do
  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 14)

  def down, do: Oban.Migrations.down(version: 12)
end
