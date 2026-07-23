defmodule Plausible.Repo.Migrations.CreateOauthTables do
  use Ecto.Migration

  def change do
    create table(:oauth_authorization_codes) do
      add :code_hash, :string, null: false
      add :client_id, :string, null: false
      add :client_name, :string
      add :redirect_uri, :string, null: false
      add :code_challenge, :string, null: false
      add :code_challenge_method, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :resource, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:oauth_authorization_codes, [:code_hash])
    create index(:oauth_authorization_codes, [:expires_at])

    create table(:oauth_access_tokens) do
      add :access_token_hash, :string, null: false
      add :access_token_prefix, :string, null: false
      add :refresh_token_hash, :string
      add :refresh_token_prefix, :string
      add :client_id, :string, null: false
      add :client_name, :string
      add :scopes, {:array, :string}, null: false, default: []
      add :resource, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :access_token_expires_at, :utc_datetime_usec, null: false
      add :refresh_token_expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:oauth_access_tokens, [:access_token_hash])
    create unique_index(:oauth_access_tokens, [:refresh_token_hash])
    create index(:oauth_access_tokens, [:access_token_expires_at])
    create index(:oauth_access_tokens, [:user_id])
  end
end
