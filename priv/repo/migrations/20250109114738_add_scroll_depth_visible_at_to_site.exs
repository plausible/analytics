defmodule Plausible.Repo.Migrations.AddScrollDepthVisibleAtToSite do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :scroll_depth_visible_at, :naive_datetime, null: true
    end
  end
end
