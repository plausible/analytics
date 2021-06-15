defmodule Plausible.Workers.LockSites do
  use Plausible.Repo
  use Oban.Worker, queue: :lock_sites

  @impl Oban.Worker
  def perform(_job) do
    users = Repo.all(from u in Plausible.Auth.User, preload: :subscription)

    for user <- users do
      Plausible.Billing.SiteLocker.check_sites_for(user)
    end

    :ok
  end
end
