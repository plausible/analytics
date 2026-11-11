defmodule Plausible.Repo.Migrations.DropAllSubscriptionsTriggers do
  use Ecto.Migration

  def change do
    execute """
            DROP TRIGGER IF EXISTS all_subscriptions_crud ON all_subscriptions
            """,
            """
            CREATE OR REPLACE TRIGGER all_subscriptions_crud
            INSTEAD OF INSERT OR UPDATE OR DELETE ON all_subscriptions 
            FOR EACH ROW
            EXECUTE FUNCTION all_subscriptions_crud_row()
            """

    execute """
            DROP FUNCTION IF EXISTS all_subscriptions_crud_row()
            """,
            """
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
            """
  end
end
