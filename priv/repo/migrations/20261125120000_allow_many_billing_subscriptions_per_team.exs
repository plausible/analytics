defmodule Plausible.Repo.Migrations.AllowManyBillingSubscriptionsPerTeam do
  use Ecto.Migration

  def up do
    drop unique_index(:billing_subscriptions, [:team_id])
    create index(:billing_subscriptions, [:team_id])

    create unique_index(:billing_subscriptions, [:team_id],
             where: "status IN ('active', 'past_due', 'paused')",
             name: :billing_subscriptions_live_team_id_index
           )

    execute all_subscriptions_view("ORDER BY bss.inserted_at DESC, bss.id DESC LIMIT 1")
  end

  def down do
    execute all_subscriptions_view("")

    drop unique_index(:billing_subscriptions, [:team_id],
           name: :billing_subscriptions_live_team_id_index
         )

    drop index(:billing_subscriptions, [:team_id])
    create unique_index(:billing_subscriptions, [:team_id])
  end

  defp all_subscriptions_view(billing_row_selection) do
    """
    CREATE OR REPLACE VIEW all_subscriptions AS
    SELECT
      COALESCE(cs.type, bs.type) AS type,
      COALESCE(cs.id, bs.id) AS id,
      cs.paddle_subscription_id,
      cs.paddle_plan_id,
      cs.update_url,
      cs.cancel_url,
      bs.billing_subscription_id,
      bs.billing_customer_id,
      bs.billing_product_id,
      bs.billing_price_id,
      COALESCE(cs.next_bill_amount, bs.next_bill_amount) AS next_bill_amount,
      COALESCE(cs.next_bill_date, bs.next_bill_date) AS next_bill_date,
      COALESCE(cs.last_bilL_date, bs.last_bill_date) AS last_bill_date,
      COALESCE(cs.currency_code, bs.currency_code) AS currency_code,
      COALESCE(cs.status, bs.status) AS status,
      t.id AS team_id,
      COALESCE(cs.inserted_at, bs.inserted_at) AS inserted_at,
      COALESCE(cs.updated_at, bs.updated_at) AS updated_at,
      bs.billing_interval
    FROM teams t
    LEFT JOIN LATERAL (
      SELECT
        'classic' AS type,
        ss.id,
        ss.paddle_subscription_id,
        ss.paddle_plan_id,
        ss.update_url,
        ss.cancel_url,
        ss.next_bill_amount,
        ss.next_bill_date,
        ss.last_bill_date,
        ss.currency_code,
        ss.status,
        ss.updated_at,
        ss.inserted_at
      FROM subscriptions ss
      WHERE ss.team_id = t.id
      ORDER BY ss.inserted_at DESC, ss.id DESC
      LIMIT 1
    ) AS cs ON t.billing_customer_id IS NULL
    LEFT JOIN LATERAL (
      SELECT
        'billing' AS type,
        bss.id,
        bss.billing_subscription_id,
        bss.billing_customer_id,
        bss.billing_product_id,
        bss.billing_price_id,
        bss.next_bill_amount,
        bss.next_bill_date,
        bss.last_bill_date,
        bss.currency_code,
        bss.status,
        bss.updated_at,
        bss.inserted_at,
        bss.billing_interval
      FROM billing_subscriptions bss
      WHERE bss.team_id = t.id AND t.billing_customer_id = bss.billing_customer_id
      #{billing_row_selection}
    ) AS bs ON t.billing_customer_id IS NOT NULL
    WHERE cs.id IS NOT NULL OR bs.id IS NOT NULL
    """
  end
end
