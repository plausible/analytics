defmodule Plausible.Repo.Migrations.AddAllSubscriptions do
  use Ecto.Migration

  def change do
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
            """,
            """
            DROP VIEW all_subscriptions
            """

    execute """
            CREATE OR REPLACE FUNCTION all_subscriptions_crud_row()
            RETURNS TRIGGER AS
            $$
            BEGIN
              IF TG_OP = 'INSERT' THEN
                IF NEW.type = 'classic' THEN
                  INSERT INTO subscriptions (
                    paddle_subscription_id,
                    paddle_plan_id,
                    update_url,
                    cancel_url,
                    status,
                    next_bill_amount,
                    next_bill_date,
                    last_bill_date,
                    currency_code,
                    team_id,
                    inserted_at,
                    updated_at
                  ) VALUES (
                    NEW.paddle_subscription_id,
                    NEW.paddle_plan_id,
                    NEW.update_url,
                    NEW.cancel_url,
                    NEW.status,
                    NEW.next_bill_amount,
                    NEW.next_bill_date,
                    NEW.last_bill_date,
                    NEW.currency_code,
                    NEW.team_id,
                    NEW.inserted_at,
                    NEW.updated_at
                  )
                  RETURNING id INTO NEW.id;

                  RETURN NEW;
                ELSIF NEW.type = 'billing' THEN
                  INSERT INTO billing_subscriptions (
                    billing_subscription_id,
                    billing_customer_id,
                    billing_product_id,
                    billing_price_id,
                    status,
                    next_bill_amount,
                    next_bill_date,
                    last_bill_date,
                    currency_code,
                    team_id,
                    inserted_at,
                    updated_at
                  ) VALUES (
                    NEW.billing_subscription_id,
                    NEW.billing_customer_id,
                    NEW.billing_product_id,
                    NEW.billing_price_id,
                    NEW.status,
                    NEW.next_bill_amount,
                    NEW.next_bill_date,
                    NEW.last_bill_date,
                    NEW.currency_code,
                    NEW.team_id,
                    NEW.inserted_at,
                    NEW.updated_at
                  )
                  RETURNING id INTO NEW.id;

                  RETURN NEW;
                END IF;
              END IF;

              IF TG_OP = 'UPDATE' THEN
                IF NEW.type = 'classic' THEN
                  UPDATE subscriptions SET
                    paddle_subscription_id = NEW.paddle_subscription_id,
                    paddle_plan_id = NEW.paddle_plan_id,
                    update_url = NEW.update_url,
                    cancel_url = NEW.cancel_url,
                    status = NEW.status,
                    next_bill_amount = NEW.next_bill_amount,
                    next_bill_date = NEW.next_bill_date,
                    last_bill_date = NEW.last_bill_date,
                    currency_code = NEW.currency_code,
                    team_id = NEW.team_id,
                    inserted_at = NEW.inserted_at,
                    updated_at = NEW.updated_at
                  WHERE id = OLD.id;

                  RETURN NEW;
                ELSIF NEW.type = 'billing' THEN
                  UPDATE billing_subscriptions SET
                    billing_subscription_id = NEW.billing_subscription_id,
                    billing_customer_id = NEW.billing_customer_id,
                    billing_product_id = NEW.billing_product_id,
                    billing_price_id = NEW.billing_price_id,
                    status = NEW.status,
                    next_bill_amount = NEW.next_bill_amount,
                    next_bill_date = NEW.next_bill_date,
                    last_bill_date = NEW.last_bill_date,
                    currency_code = NEW.currency_code,
                    team_id = NEW.team_id,
                    inserted_at = NEW.inserted_at,
                    updated_at = NEW.updated_at
                  WHERE id = OLD.id;

                  RETURN NEW;
                END IF;
              END IF;

              IF TG_OP = 'DELETE' THEN
                IF OLD.type = 'classic' THEN
                  DELETE FROM subscriptions WHERE id = OLD.id;
                  RETURN OLD;
                ELSIF OLD.type = 'billing' THEN
                  DELETE FROM billing_subscriptions WHERE id = OLD.id;
                  RETURN OLD;
                END IF;
              END IF;

              RETURN NULL;
            END;
            $$
            LANGUAGE plpgsql
            """,
            """
            DROP FUNCTION IF EXISTS all_subscriptions_crud_row()
            """

    execute """
            CREATE OR REPLACE TRIGGER all_subscriptions_crud
            INSTEAD OF INSERT OR UPDATE OR DELETE ON all_subscriptions 
            FOR EACH ROW
            EXECUTE FUNCTION all_subscriptions_crud_row()
            """,
            """
            DROP TRIGGER IF EXISTS all_subscriptions_crud ON all_subscriptions
            """
  end
end
