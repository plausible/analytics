defmodule Plausible.Repo.Migrations.AddNewVisitorToPageviews do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:pageviews) do
      add :new_visitor, :boolean
    end
    flush()
    Plausible.Repo.update_all(Plausible.Pageview, [set: [new_visitor: true]])
    flush()
    alter table(:pageviews) do
      modify :new_visitor, :boolean, null: false
    end
  end
end
