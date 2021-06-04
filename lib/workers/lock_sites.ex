defmodule Plausible.Workers.LockSites do
  use Plausible.Repo
  use Oban.Worker, queue: :lock_sites

  @impl Oban.Worker
  def perform(_job) do
    users = Repo.all(from u in Plausible.Auth.User, preload: :subscription)

    for user <- users do
      if Plausible.Billing.needs_to_upgrade?(user) do
        set_lock_status_for(user, true)
      else
        set_lock_status_for(user, false)
      end
    end

    :ok
  end

  defp set_lock_status_for(user, status) do
    site_ids =
      Repo.all(
        from s in Plausible.Site.Membership,
          where: s.user_id == ^user.id,
          where: s.role == :owner,
          select: s.site_id
      )

    site_q =
      from(
        s in Plausible.Site,
        where: s.id in ^site_ids
      )

    Repo.update_all(site_q, set: [locked: status])
  end
end
