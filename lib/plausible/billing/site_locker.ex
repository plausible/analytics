defmodule Plausible.Billing.SiteLocker do
  use Plausible.Repo

  alias Plausible.Teams

  @type update_opt() :: {:send_email?, boolean()}

  @type lock_reason() ::
          :grace_period_ended_now
          | :grace_period_ended_already
          | :no_trial
          | :no_active_subscription

  @spec update_sites_for(Teams.Team.t(), [update_opt()]) ::
          {:locked, lock_reason()} | :unlocked
  def update_sites_for(team, opts \\ []) do
    send_email? = Keyword.get(opts, :send_email?, true)

    team = Teams.with_subscription(team)

    case Plausible.Teams.Billing.check_needs_to_upgrade(team) do
      {:needs_to_upgrade, :grace_period_ended} ->
        set_lock_status_for(team, true)

        if team.grace_period.is_over != true do
          Plausible.Teams.end_grace_period(team)

          if send_email? do
            team = Repo.preload(team, :owner)
            send_grace_period_end_email(team)
          end

          {:locked, :grace_period_ended_now}
        else
          {:locked, :grace_period_ended_already}
        end

      {:needs_to_upgrade, reason} ->
        set_lock_status_for(team, true)
        {:locked, reason}

      :no_upgrade_needed ->
        set_lock_status_for(team, false)
        :unlocked
    end
  end

  @spec set_lock_status_for(Teams.Team.t(), boolean()) :: {:ok, non_neg_integer()}
  def set_lock_status_for(team, status) do
    site_ids = Teams.owned_sites_ids(team)

    site_q =
      from(
        s in Plausible.Site,
        where: s.id in ^site_ids
      )

    {num_updated, _} = Repo.update_all(site_q, set: [locked: status])

    {:ok, num_updated}
  end

  defp send_grace_period_end_email(team) do
    usage = Teams.Billing.monthly_pageview_usage(team)
    suggested_plan = Plausible.Billing.Plans.suggest(team, usage.last_cycle.total)

    team.owner
    |> PlausibleWeb.Email.dashboard_locked(usage, suggested_plan)
    |> Plausible.Mailer.send()
  end
end
