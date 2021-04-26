defmodule Plausible.Repo.Migrations.UpdateObanJobsToV9 do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 9)
  end

  def down do
    Oban.Migrations.down(version: 9)
  end
end
