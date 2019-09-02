defmodule Plausible.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :paddle_subscription_id, :string, null: false
      add :paddle_plan_id, :string, null: false
      add :user_id, references(:users), null: false
      add :update_url, :text, null: false
      add :cancel_url, :text, null: false
      add :status, :string, null: false
      add :next_bill_amount, :string, null: false
      add :next_bill_date, :date, null: false

      timestamps()
    end

    create unique_index(:subscriptions, [:paddle_subscription_id])
  end
end
