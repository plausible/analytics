defmodule Plausible.Repo.Migrations.UpgradeObanJobsToV12 do
  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 12)

  def down, do: Oban.Migrations.down(version: 11)
end
