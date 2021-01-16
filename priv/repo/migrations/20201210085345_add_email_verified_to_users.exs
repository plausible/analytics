defmodule Plausible.Repo.Migrations.AddEmailVerifiedToUsers do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:users) do
      add :email_verified, :boolean, null: false, default: false
    end

    flush()

    Repo.update_all("users", set: [email_verified: true])
  end
end
