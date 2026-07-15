defmodule Plausible.Workers.ScoreTrialProspects do
  @moduledoc """
  Daily worker that scores the revenue potential of every team on (or just off)
  a trial and caches the result in the `trial_prospects` table.
  """
  use Plausible.Repo

  use Oban.Worker,
    queue: :score_trial_prospects,
    max_attempts: 1

  require Logger

  alias Plausible.Teams
  alias Plausible.CustomerSupport.{TrialProspect, TrialProspects}

  @max_expired_days 30

  @impl Oban.Worker
  def perform(_job) do
    Date.utc_today()
    |> trial_population()
    |> Enum.each(&score_and_persist/1)

    :ok
  end

  defp score_and_persist(team) do
    try do
      team
      |> score_team()
      |> upsert()
    rescue
      error ->
        Logger.error(
          "ScoreTrialProspects: skipping team #{team.id}: " <>
            Exception.format(:error, error, __STACKTRACE__)
        )
    end
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
      %{events_in_window: 0} -> nil
      traffic -> build_row(team, traffic, site_ids)
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

  defp upsert(nil), do: :ok

  defp upsert(row) do
    Repo.insert_all(TrialProspect, [row],
      on_conflict: {:replace_all_except, [:id, :team_id, :inserted_at]},
      conflict_target: :team_id
    )
  end
end
