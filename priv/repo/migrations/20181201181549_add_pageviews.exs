defmodule Plausible.Repo.Migrations.AddPageviews do
  use Ecto.Migration

  def change do
    create table(:pageviews) do
      add :hostname, :text, null: false
      add :pathname, :text, null: false
      add :referrer, :text
      add :user_agent, :text
      add :screen_width, :integer
      add :screen_height, :integer

      timestamps()
    end
  end
end
