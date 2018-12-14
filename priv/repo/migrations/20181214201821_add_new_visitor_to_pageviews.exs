defmodule Neatmetrics.Repo.Migrations.AddNewVisitorToPageviews do
  use Ecto.Migration
  use Neatmetrics.Repo

  def change do
    alter table(:pageviews) do
      add :new_visitor, :boolean
    end
    flush()
    Neatmetrics.Repo.update_all(Neatmetrics.Pageview, [set: [new_visitor: true]])
    flush()
    alter table(:pageviews) do
      modify :new_visitor, :boolean, null: false
    end
  end
end
