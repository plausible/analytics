defmodule Neatmetrics.Repo.Migrations.AddUidToPageviews do
  use Ecto.Migration
  use Neatmetrics.Repo

  def change do
    alter table(:pageviews) do
      add :user_id, :string
    end

    flush()

    Repo.update_all(Neatmetrics.Pageview, set: [user_id: "dummy"])

    alter table(:pageviews) do
      modify :user_id, :string, null: false
    end
  end
end
