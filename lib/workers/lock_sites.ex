defmodule Plausible.Workers.LockSites do
  use Plausible.Repo
  use Oban.Worker, queue: :lock_sites

  @impl Oban.Worker
  def perform(_job) do
    subscription_q = from(s in Plausible.Billing.Subscription, order_by: [desc: s.inserted_at])
    users = Repo.all(from u in Plausible.Auth.User, preload: [subscription: ^subscription_q])

    for user <- users do
      Plausible.Billing.SiteLocker.check_sites_for(user)
    end

    :ok
  end
end
