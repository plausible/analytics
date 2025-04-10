defmodule Plausible.Workers.LockSites do
  use Plausible.Repo
  use Oban.Worker, queue: :lock_sites

  alias Plausible.Teams

  @impl Oban.Worker
  def perform(_job) do
    teams =
      Repo.all(
        from t in Teams.Team,
          as: :team,
          left_lateral_join: s in subquery(Teams.last_subscription_join_query()),
          on: true,
          preload: [subscription: s]
      )

    for team <- teams do
      Plausible.Billing.SiteLocker.update_for(team)
    end

    :ok
  end
end
