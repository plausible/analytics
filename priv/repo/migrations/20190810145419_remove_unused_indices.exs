defmodule Plausible.Repo.Migrations.RemoveUnusedIndices do
  use Ecto.Migration

  def change do
    drop index(:pageviews, [:referrer])
    drop index(:pageviews, [:referrer_source])
  end
end
