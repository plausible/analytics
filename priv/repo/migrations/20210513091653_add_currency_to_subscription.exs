defmodule Plausible.Repo.Migrations.AddCurrencyToSubscription do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add :currency_code, :string
    end

    execute "UPDATE subscriptions set currency_code='USD'"

    alter table(:subscriptions) do
      modify :currency_code, :string, null: false
    end
  end
end
