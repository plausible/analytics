defmodule Plausible.Repo.Migrations.AddNameToEvents do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:events) do
      add :name, :string
    end

    flush()

    Repo.update_all(Plausible.Event, set: [name: "pageview"])

    flush()

    alter table(:events) do
      modify :name, :string, null: false
    end
  end
end
