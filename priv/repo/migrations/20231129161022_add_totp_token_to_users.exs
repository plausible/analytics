defmodule Plausible.Repo.Migrations.AddTotpTokenToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_token, :string
    end
  end
end
