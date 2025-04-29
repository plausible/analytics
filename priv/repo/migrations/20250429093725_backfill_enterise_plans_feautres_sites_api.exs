defmodule Plausible.Repo.Migrations.BackfillEnterisePlansFeautresSitesApi do
  use Ecto.Migration

  def change do
    execute """
            UPDATE enterprise_plans ep SET features = array_append(features, 'sites_api')
            WHERE
              'stats_api' = ANY(features) AND
              EXISTS (
                SELECT 1 FROM team_memberships AS tm
                WHERE 
                  tm.team_id = ep.team_id AND
                  EXISTS(
                    SELECT 1 FROM api_keys ak
                    WHERE
                      ak.user_id = tm.user_id AND
                      'sites:provision:*' = ANY(ak.scopes)
                  )
              )
            """,
            """
            UPDATE enterprise_plans SET features = array(
              SELECT unnest(features) EXCEPT SELECT unnest('{"sites_api"}'::varchar[])
            )
            """
  end
end
