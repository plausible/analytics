defmodule Plausible.Billing.SiteLocker do
  use Plausible.Repo

  @type update_opt() :: {:send_email?, boolean()}

  @type lock_reason() ::
          :grace_period_ended_now
          | :grace_period_ended_already
          | :no_trial
          | :no_active_subscription

  @spec update_sites_for(Plausible.Auth.User.t(), [update_opt()]) ::
          {:locked, lock_reason()} | :unlocked
  def update_sites_for(user, opts \\ []) do
    send_email? = Keyword.get(opts, :send_email?, true)

    user = Plausible.Users.with_subscription(user)

    case Plausible.Billing.check_needs_to_upgrade(user) do
      {:needs_to_upgrade, :grace_period_ended} ->
        set_lock_status_for(user, true)

        if user.grace_period.is_over != true do
          Plausible.Users.end_grace_period(user)

          if send_email? do
            send_grace_period_end_email(user)
          end

          {:locked, :grace_period_ended_now}
        else
          {:locked, :grace_period_ended_already}
        end

      {:needs_to_upgrade, reason} ->
        set_lock_status_for(user, true)
        {:locked, reason}

      :no_upgrade_needed ->
        set_lock_status_for(user, false)
        :unlocked
    end
  end

  @spec set_lock_status_for(Plausible.Auth.User.t(), boolean()) :: {:ok, non_neg_integer()}
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

    {num_updated, _} = Repo.update_all(site_q, set: [locked: status])

    {:ok, num_updated}
  end

  @spec send_grace_period_end_email(Plausible.Auth.User.t()) :: Plausible.Mailer.result()
  def send_grace_period_end_email(user) do
    usage = Plausible.Billing.Quota.Usage.monthly_pageview_usage(user)
    suggested_plan = Plausible.Billing.Plans.suggest(user, usage.last_cycle.total)

    PlausibleWeb.Email.dashboard_locked(user, usage, suggested_plan)
    |> Plausible.Mailer.send()
  end
end
