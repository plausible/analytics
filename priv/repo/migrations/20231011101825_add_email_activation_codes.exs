defmodule Plausible.Repo.Migrations.AddEmailActivationCodes do
  use Ecto.Migration

  def change do
    create table(:email_activation_codes) do
      add :code, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :issued_at, :naive_datetime, null: false
    end

    create unique_index(:email_activation_codes, :user_id)
  end
end
