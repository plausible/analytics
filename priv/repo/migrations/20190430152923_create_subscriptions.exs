defmodule Plausible.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :paddle_subscription_id, :string, null: false
      add :paddle_plan_id, :string, null: false
      add :user_id, references(:users), null: false
      add :update_url, :string, null: false
      add :cancel_url, :string, null: false
      add :status, :string, null: false

      timestamps()
    end

    create unique_index(:subscriptions, [:paddle_subscription_id])
    create unique_index(:subscriptions, [:user_id])
  end
end
