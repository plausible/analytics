defmodule Plausible.Repo.Migrations.AllowSameTeamDomainSwap do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION check_domain() RETURNS TRIGGER AS $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM sites
         WHERE (NEW.domain = domain_changed_from AND NEW.id != id AND (team_id IS NULL OR NEW.team_id IS NULL OR team_id != NEW.team_id))
         OR (OLD IS NULL AND NEW.domain_changed_from = domain)
      ) THEN
        RAISE unique_violation USING CONSTRAINT = 'domain_change_disallowed';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)
  end

  def down do
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
  end
end
