defmodule Plausible.Repo.Migrations.AddLastUsedAtToOauthAccessTokens do
  use Ecto.Migration

  def change do
    alter table(:oauth_access_tokens) do
      add :last_used_at, :utc_datetime_usec
    end
  end
end
