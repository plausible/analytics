defmodule :"Elixir.Plausible.Repo.Migrations.Associate-goals-with-sites" do
  use Ecto.Migration

  def up do
    alter table(:goals) do
      add :site_id, :integer, null: true
    end

    execute """
    DELETE FROM goals g WHERE NOT EXISTS (
      SELECT 1 FROM sites s
      WHERE s.domain = g.domain
    )
    """

    execute """
    UPDATE goals g SET site_id = (
      SELECT s.id FROM sites s WHERE s.domain = g.domain
    )
    """
  end

  def down do
    alter table(:goals) do
      remove :site_id
    end
  end
end
