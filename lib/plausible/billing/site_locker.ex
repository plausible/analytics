defmodule Plausible.Billing.SiteLocker do
  use Plausible.Repo

  def check_sites_for(user) do
    case Plausible.Billing.needs_to_upgrade?(user) do
      {true, :grace_period_ended} ->
        set_lock_status_for(user, true)

        if !user.grace_period.is_over do
          send_grace_period_end_email(user)
          Plausible.Auth.User.end_grace_period(user) |> Repo.update()
        end

      {true, _} ->
        set_lock_status_for(user, true)

      _ ->
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

  defp send_grace_period_end_email(user) do
    {_, last_cycle} = Plausible.Billing.last_two_billing_cycles(user)
    {_, last_cycle_usage} = Plausible.Billing.last_two_billing_months_usage(user)
    suggested_plan = Plausible.Billing.Plans.suggested_plan(user, last_cycle_usage)

    template =
      PlausibleWeb.Email.dashboard_locked(
        user,
        last_cycle_usage,
        last_cycle,
        suggested_plan
      )

    Plausible.Mailer.send_email_safe(template)
  end
end
