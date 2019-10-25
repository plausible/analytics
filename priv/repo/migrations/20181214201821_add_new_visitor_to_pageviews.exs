defmodule Plausible.Repo.Migrations.AddNewVisitorToPageviews do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:pageviews) do
      add :new_visitor, :boolean, null: false
    end
  end
end
