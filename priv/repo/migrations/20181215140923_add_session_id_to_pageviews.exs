defmodule Plausible.Repo.Migrations.AddSessionIdToPageviews do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      add :session_id, :string
    end
    flush()
    Plausible.Repo.update_all(Plausible.Pageview, [set: [session_id: "123"]])
    flush()
    alter table(:pageviews) do
      modify :session_id, :string, null: false
    end
  end
end
