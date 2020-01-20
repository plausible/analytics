defmodule Plausible.Repo.Migrations.ChangeSessionReferrerToText do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      modify :referrer, :text
    end
  end
end
