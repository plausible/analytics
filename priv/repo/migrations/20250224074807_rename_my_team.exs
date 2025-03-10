defmodule Plausible.Repo.Migrations.RenameMyTeam do
  use Ecto.Migration

  def up do
    execute """
    UPDATE teams SET name = 'My Personal Sites' WHERE name = 'My Team'
    """
  end

  def down do
    execute """
    UPDATE teams SET name = 'My Team' WHERE name = 'My Personal Sites'
    """
  end
end
