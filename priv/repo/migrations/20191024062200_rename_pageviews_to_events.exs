defmodule Plausible.Repo.Migrations.RenamePageviewsToEvents do
  use Ecto.Migration

  def change do
    rename table("pageviews"), to: table("events")
  end
end
