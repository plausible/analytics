defmodule Plausible.Repo.Migrations.AllowDomainChange do
  use Ecto.Migration

  def up do
    alter table(:sites) do
      add(:domain_changed_from, :string, null: true)
      add(:domain_changed_at, :naive_datetime, null: true)
    end

    create(unique_index(:sites, :domain_changed_from))
    create(index(:sites, :domain_changed_at))

    execute("""
    CREATE OR REPLACE FUNCTION check_domain() RETURNS TRIGGER AS $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM sites
         WHERE (NEW.domain = domain_changed_from AND NEW.id != id)
         OR (OLD IS NULL AND NEW.domain_changed_from = domain)
      ) THEN
        RAISE unique_violation USING CONSTRAINT = 'domain_change_disallowed';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER check_domain_trigger
    BEFORE INSERT OR UPDATE ON sites
    FOR EACH ROW EXECUTE FUNCTION check_domain();
    """)
  end

  def down do
    execute("""
    DROP TRIGGER check_domain_trigger ON sites
    """)

    execute("""
    DROP FUNCTION check_domain()
    """)

    alter table(:sites) do
      remove(:domain_changed_from)
      remove(:domain_changed_at)
    end
  end
end
