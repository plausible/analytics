defmodule Plausible.Repo.Migrations.DropEventsHostnameIndex do
  use Ecto.Migration

  def change do
    drop index("pageviews", :hostname)
  end
end
