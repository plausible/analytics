defmodule Plausible.Repo.Migrations.CreateBillingWebhookFailures do
  use Ecto.Migration

  def change do
    create table(:billing_webhook_failures) do
      add :billing_event_id, :string
      add :event_type, :string
      add :payload, :jsonb, null: false
      add :error, :text, null: false

      timestamps(updated_at: false)
    end

    create index(:billing_webhook_failures, [:billing_event_id])
  end
end
