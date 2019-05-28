defmodule Plausible.Repo.Migrations.AddUidToPageviews do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:pageviews) do
      add :user_id, :binary_id
    end

    flush()

    Repo.update_all(Plausible.Pageview, set: [user_id: "00029281-7f8b-462d-a9f0-0d2ddfc6ea02"])

    alter table(:pageviews) do
      modify :user_id, :string, null: false
    end
  end
end
