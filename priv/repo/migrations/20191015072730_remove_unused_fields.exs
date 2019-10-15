defmodule Plausible.Repo.Migrations.RemoveUnusedFields do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      remove :raw_referrer
      remove :screen_width
      remove :user_agent
    end
  end
end
