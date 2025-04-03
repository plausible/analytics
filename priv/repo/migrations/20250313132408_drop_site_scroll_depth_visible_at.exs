defmodule Plausible.Repo.Migrations.DropSiteScrollDepthVisibleAt do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      remove :scroll_depth_visible_at
    end
  end
end
