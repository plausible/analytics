defmodule Plausible.Repo.Migrations.ConsolidatedViewRegularSiteCountCheck do
  use Ecto.Migration

  def change do
    execute """
              CREATE OR REPLACE FUNCTION check_consolidated_sites_constraint(p_team_id BIGINT, p_consolidated BOOLEAN)
              RETURNS BOOLEAN AS $$
              BEGIN
                IF p_consolidated = true THEN
                  RETURN (
                    SELECT COUNT(*) 
                    FROM sites 
                    WHERE team_id = p_team_id 
                      AND consolidated = false
                  ) >= 2;
                END IF;
                RETURN true;
              END;
              $$ LANGUAGE plpgsql;
            """,
            """
              DROP FUNCTION IF EXISTS check_consolidated_sites_constraint(BIGINT, BOOLEAN);
            """

    execute """
              ALTER TABLE sites 
              ADD CONSTRAINT consolidated_sites_check 
              CHECK (check_consolidated_sites_constraint(team_id, consolidated))
            """,
            """
              ALTER TABLE sites 
              DROP CONSTRAINT IF EXISTS consolidated_sites_check
            """
  end
end
