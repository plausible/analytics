defmodule Plausible.Repo.Migrations.RenameMyTeam do
  use Ecto.Migration

  def up do
    execute """
    UPDATE teams SET name = 'Meine Websites' WHERE name = 'My Team'
    """
  end

  def down do
    execute """
    UPDATE teams SET name = 'My Team' WHERE name = 'Meine Websites'
    """
  end
end
