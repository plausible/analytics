defmodule Plausible.Repo.Migrations.AddIndexToPageviews do
  use Ecto.Migration

  def change do
    create index("pageviews", [:hostname])
  end
end
