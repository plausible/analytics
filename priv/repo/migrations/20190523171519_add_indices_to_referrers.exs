defmodule Plausible.Repo.Migrations.AddIndicesToReferrers do
  use Ecto.Migration

  def change do
    create index(:pageviews, :referrer_source)
    create index(:pageviews, :referrer)
  end
end
