defmodule Plausible.Repo.Migrations.RemoveScreenHeightFromPageviews do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      remove :screen_height
    end
  end
end
