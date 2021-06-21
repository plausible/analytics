defmodule Plausible.Billing.SiteLocker do
  use Plausible.Repo

  def check_sites_for(user) do
    if Plausible.Billing.needs_to_upgrade?(user) do
      set_lock_status_for(user, true)
    else
      set_lock_status_for(user, false)
    end
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
