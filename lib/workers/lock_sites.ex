defmodule Plausible.Workers.LockSites do
  @moduledoc false

  use Plausible.Repo
  use Oban.Worker, queue: :lock_sites

  alias Plausible.Billing.EnterprisePlan
  alias Plausible.Teams

  @impl Oban.Worker
  def perform(_job) do
    teams =
      Repo.all(
        from t in Teams.Team,
          as: :team,
          left_join: s in assoc(t, :subscription),
          left_join: ep in EnterprisePlan,
          on: ep.team_id == t.id and ep.paddle_plan_id == s.paddle_plan_id,
          preload: [subscription: s, enterprise_plan: ep]
      )

    for team <- teams do
      Plausible.Billing.SiteLocker.update_for(team)
    end

    :ok
  end
end
