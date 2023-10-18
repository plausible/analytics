defmodule Plausible.Repo.Migrations.AddLastUsedAtToPluginsApiTokens do
  use Ecto.Migration

  def change do
    alter table("plugins_api_tokens") do
      add(:last_seen_at, :naive_datetime)
    end
  end
end
