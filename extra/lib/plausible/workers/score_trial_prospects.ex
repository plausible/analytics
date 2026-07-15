defmodule Plausible.Workers.ScoreTrialProspects do
  @moduledoc """
  Daily worker that scores the revenue potential of every team on (or just off)
  a trial and caches the result in the `trial_prospects` table.
  """
  use Plausible.Repo

  use Oban.Worker,
    queue: :score_trial_prospects,
    max_attempts: 1

  alias Plausible.Teams
  alias Plausible.CustomerSupport.{TrialProspect, TrialProspects}

  @max_expired_days 30

  @impl Oban.Worker
  def perform(_job) do
    rows =
      Date.utc_today()
      |> trial_population()
      |> Enum.flat_map(&score_team/1)

    persist(rows)
    :ok
  end

  defp trial_population(today) do
    cutoff = Date.add(today, -@max_expired_days)

    Repo.all(
      from t in Teams.Team,
        left_join: s in assoc(t, :subscription),
        where: not is_nil(t.trial_expiry_date),
        where: is_nil(s.id),
        where: t.trial_expiry_date >= ^cutoff
    )
  end

  defp score_team(team) do
    site_ids = Teams.owned_sites_ids(team)

    traffic = Plausible.Stats.Clickhouse.trial_traffic(site_ids)

    case traffic do
      %{events_in_window: 0} -> []
      traffic -> [build_row(team, traffic, site_ids)]
    end
  end

  defp build_row(team, traffic, site_ids) do
    score =
      TrialProspects.score(
        traffic.estimated_monthly,
        Teams.Billing.features_usage(team, site_ids),
        length(site_ids),
        Teams.Billing.team_member_usage(team)
      )

    now = DateTime.utc_now(:second)
    naive_now = DateTime.to_naive(now)

    %{
      team_id: team.id,
      estimated_monthly: traffic.estimated_monthly,
      observed_days: traffic.observed_days,
      first_data_day: traffic.first_data_day,
      kind: score.kind,
      forced_by: score.forced_by,
      pageview_limit: score.pageview_limit,
      over_top_tier: score.over_top_tier,
      estimated_mrr: score.estimated_mrr,
      computed_at: now,
      inserted_at: naive_now,
      updated_at: naive_now
    }
  end

  defp persist(rows) do
    scored_team_ids = Enum.map(rows, & &1.team_id)

    Repo.transaction(fn ->
      Repo.insert_all(TrialProspect, rows,
        on_conflict: {:replace_all_except, [:id, :team_id, :inserted_at]},
        conflict_target: :team_id
      )

      Repo.delete_all(from p in TrialProspect, where: p.team_id not in ^scored_team_ids)
    end)
  end
end
