defmodule Plausible.Repo.Migrations.AddActivationPins do
  use Ecto.Migration

  def change do
    create table(:activation_pins, primary_key: false) do
      add :pin, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :issued_at, :naive_datetime
    end

    execute "INSERT INTO activation_pins (pin) SELECT pin FROM GENERATE_SERIES (1000, 9999) AS s(pin) order by random();"
  end
end
