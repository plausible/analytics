defmodule Plausible.Repo.Migrations.AddClientNameToOauthTables do
  use Ecto.Migration

  def change do
    alter table(:oauth_authorization_codes) do
      add :client_name, :string
    end

    alter table(:oauth_access_tokens) do
      add :client_name, :string
    end
  end
end
