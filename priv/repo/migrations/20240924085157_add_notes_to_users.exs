defmodule Plausible.Repo.Migrations.AddNotesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :notes, :text
    end
  end
end
