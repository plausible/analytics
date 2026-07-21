defmodule Plausible.Repo.Migrations.CreateOauthAuthorizationCodes do
  use Ecto.Migration

  def change do
    create table(:oauth_authorization_codes) do
      add :code_hash, :string, null: false
      add :client_id, :string, null: false
      add :redirect_uri, :string, null: false
      add :code_challenge, :string, null: false
      add :code_challenge_method, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :resource, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :team_id, references(:teams, on_delete: :delete_all)
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:oauth_authorization_codes, [:code_hash])
    create index(:oauth_authorization_codes, [:expires_at])
  end
end
