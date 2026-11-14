defmodule Plausible.Repo.Migrations.AddBillingIntervalToBillingSubscriptions do
  use Ecto.Migration

  def up do
    alter table(:billing_subscriptions) do
      add :billing_interval, :string, null: false
    end

    execute """
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
    ) AS bs ON t.billing_customer_id IS NOT NULL
    WHERE cs.id IS NOT NULL OR bs.id IS NOT NULL
    """
  end

  def down do
    execute "DROP VIEW all_subscriptions"

    execute """
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
      COALESCE(cs.updated_at, bs.updated_at) AS updated_at
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
        bss.inserted_at
      FROM billing_subscriptions bss
      WHERE bss.team_id = t.id AND t.billing_customer_id = bss.billing_customer_id
    ) AS bs ON t.billing_customer_id IS NOT NULL
    WHERE cs.id IS NOT NULL OR bs.id IS NOT NULL
    """

    alter table(:billing_subscriptions) do
      remove :billing_interval
    end
  end
end
