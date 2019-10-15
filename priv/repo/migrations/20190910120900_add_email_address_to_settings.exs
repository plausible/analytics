defmodule Plausible.Repo.Migrations.AddEmailAddressToSettings do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:email_settings) do
      add :email, :citext
    end

    flush()

    alter table(:email_settings) do
      modify :email, :citext, null: false
    end
  end
end
