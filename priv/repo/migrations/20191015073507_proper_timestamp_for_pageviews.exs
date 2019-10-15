defmodule Plausible.Repo.Migrations.ProperTimestampForPageviews do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      remove :updated_at
    end

    rename table(:pageviews), :inserted_at, to: :timestamp
  end
end
