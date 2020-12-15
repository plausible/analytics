defmodule Plausible.Repo.Migrations.AddEmailVerificationCodes do
  use Ecto.Migration

  def up do
    create table(:email_verification_codes, primary_key: false) do
      add :code, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :issued_at, :naive_datetime
    end

    execute "INSERT INTO email_verification_codes (code) SELECT code FROM GENERATE_SERIES (1000, 9999) AS s(code) order by random();"
  end

  def down do
    drop table(:email_verification_codes)
  end
end
