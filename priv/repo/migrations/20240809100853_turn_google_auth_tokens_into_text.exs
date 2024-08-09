defmodule Plausible.Repo.Migrations.TurnGoogleAuthTokensIntoText do
  use Ecto.Migration

  def change do
    alter table(:google_auth) do
      modify :refresh_token, :text
      modify :access_token, :text
    end
  end
end
