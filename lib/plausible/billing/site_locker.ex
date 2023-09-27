defmodule Plausible.Billing.SiteLocker do
  use Plausible.Repo

  def check_sites_for(user, opts \\ []) do
    send_email? = Keyword.get(opts, :send_email?, true)

    user = Plausible.Users.with_subscription(user)

    case Plausible.Billing.needs_to_upgrade?(user) do
      {true, :grace_period_ended} ->
        set_lock_status_for(user, true)

        if user.grace_period.is_over != true do
          user
          |> Plausible.Auth.GracePeriod.end_changeset()
          |> Repo.update!()

          if send_email? do
            send_grace_period_end_email(user)
          end

          {:locked, :grace_period_ended_now}
        else
          {:locked, :grace_period_ended_already}
        end

      {true, reason} ->
        set_lock_status_for(user, true)
        {:locked, reason}

      {false, _} ->
        set_lock_status_for(user, false)
        {:unlocked, nil}
    end
  end

  def set_lock_status_for(user, status) do
    site_ids =
      Repo.all(
        from(s in Plausible.Site.Membership,
          where: s.user_id == ^user.id,
          where: s.role == :owner,
          select: s.site_id
        )
      )

    site_q =
      from(
        s in Plausible.Site,
        where: s.id in ^site_ids
      )

    Repo.update_all(site_q, set: [locked: status])
  end

  def send_grace_period_end_email(user) do
    {_, last_cycle} = Plausible.Billing.last_two_billing_cycles(user)
    {_, last_cycle_usage} = Plausible.Billing.last_two_billing_months_usage(user)
    suggested_plan = Plausible.Billing.Plans.suggest(user, last_cycle_usage)

    template =
      PlausibleWeb.Email.dashboard_locked(
        user,
        last_cycle_usage,
        last_cycle,
        suggested_plan
      )

    Plausible.Mailer.send(template)
  end
end
