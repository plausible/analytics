defmodule Plausible.Repo.Migrations.AddPaddleBillingSchemas do
  use Ecto.Migration

  def change do
    create table(:billing_subscriptions) do
      add :billing_subscription_id, :string, null: false
      add :billing_customer_id, :string, null: false
      add :billing_product_id, :string, null: false
      add :billing_price_id, :string, null: false
      add :next_bill_amount, :string, null: false
      add :next_bill_date, :date, null: false
      add :last_bill_date, :date
      add :currency_code, :string, null: false

      add :status, :string, null: false

      add :team_id, references(:teams), null: false

      timestamps()
    end

    create unique_index(:billing_subscriptions, [:team_id])
    create unique_index(:billing_subscriptions, [:billing_subscription_id])
    create index(:billing_subscriptions, [:billing_product_id, :billing_price_id])

    create table(:billing_subscription_events) do
      add :billing_event_id, :string, null: false

      add :billing_subscription_id, :string, null: false
      add :billing_customer_id, :string, null: false
      add :billing_product_id, :string, null: false
      add :billing_price_id, :string, null: false
      add :next_bill_amount, :string, null: false
      add :next_bill_date, :date, null: false
      add :last_bill_date, :date
      add :currency_code, :string, null: false

      add :status, :string, null: false

      add :original_event_type, :string, null: false
      add :original_event, :jsonb, null: false
      add :occurred_at, :naive_datetime_usec, null: false

      add :team_id, references(:teams), null: false

      timestamps()
    end

    create unique_index(:billing_subscription_events, [:billing_event_id])
    create index(:billing_subscription_events, [:team_id])
    create index(:billing_subscription_events, [:original_event_type])

    alter table(:teams) do
      add :billing_customer_id, :string
    end

    create index(:teams, [:billing_customer_id])
  end
end
