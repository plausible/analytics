defmodule Plausible.Repo.Migrations.CreateOauthTables do
  use Ecto.Migration

  def change do
    create table(:oauth_authorization_codes) do
      add :code_hash, :string, null: false
      add :client_id, :text, null: false
      add :client_name, :text
      add :redirect_uri, :text, null: false
      add :code_challenge, :string, null: false
      add :code_challenge_method, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :resource, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :expires_at, :naive_datetime, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:oauth_authorization_codes, [:code_hash])
    create index(:oauth_authorization_codes, [:expires_at])
    create index(:oauth_authorization_codes, [:user_id])
    create index(:oauth_authorization_codes, [:team_id])

    create table(:oauth_grants) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :client_id, :text, null: false
      add :client_name, :text
      add :scopes, {:array, :string}, null: false, default: []
      add :resource, :text, null: false

      add :access_token_hash, :string, null: false
      add :access_token_hint, :string, null: false
      add :access_token_expires_at, :naive_datetime, null: false

      add :refresh_token_hash, :string, null: false
      add :refresh_token_hint, :string, null: false
      add :refresh_token_expires_at, :naive_datetime, null: false

      add :previous_refresh_token_hash, :string
      add :rotated_at, :naive_datetime
      add :revoked_at, :naive_datetime
      add :last_used_at, :naive_datetime

      timestamps()
    end

    create unique_index(:oauth_grants, [:access_token_hash])
    create unique_index(:oauth_grants, [:refresh_token_hash])

    create unique_index(:oauth_grants, [:previous_refresh_token_hash],
             where: "previous_refresh_token_hash IS NOT NULL"
           )

    create index(:oauth_grants, [:refresh_token_expires_at])
    create index(:oauth_grants, [:user_id])
    create index(:oauth_grants, [:team_id])
  end
end
