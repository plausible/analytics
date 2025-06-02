defmodule Plausible.Billing.SiteLocker do
  use Plausible.Repo

  alias Plausible.Teams

  @type update_opt() :: {:send_email?, boolean()}

  @type lock_reason() ::
          :grace_period_ended_now
          | :grace_period_ended_already
          | :no_trial
          | :no_active_subscription

  @spec update_for(Teams.Team.t(), [update_opt()]) ::
          {:locked, lock_reason()} | :unlocked
  def update_for(team, opts \\ []) do
    send_email? = Keyword.get(opts, :send_email?, true)
    usage_mod = Keyword.get(opts, :usage_mod, Teams.Billing)

    team = Teams.with_subscription(team)

    case Teams.Billing.check_needs_to_upgrade(team, usage_mod) do
      {:needs_to_upgrade, :grace_period_ended} ->
        set_lock_status_for(team, true)

        if team.grace_period.is_over != true do
          Teams.end_grace_period(team)

          send_grace_period_end_email(team, send_email?)

          {:locked, :grace_period_ended_now}
        else
          {:locked, :grace_period_ended_already}
        end

      {:needs_to_upgrade, reason} ->
        if Teams.owned_sites_count(team) > 0 do
          set_lock_status_for(team, true)
          {:locked, reason}
        else
          set_lock_status_for(team, false)
          :unlocked
        end

      :no_upgrade_needed ->
        set_lock_status_for(team, false)
        :unlocked
    end
  end

  @spec set_lock_status_for(Teams.Team.t(), boolean()) :: :ok
  def set_lock_status_for(team, status) do
    query = from(t in Teams.Team, where: t.id == ^team.id)

    {_, _} = Repo.update_all(query, set: [locked: status])

    :ok
  end

  defp send_grace_period_end_email(team, true) do
    team = Repo.preload(team, [:owners, :billing_members])
    usage = Teams.Billing.monthly_pageview_usage(team)
    suggested_volume = Plausible.Billing.Plans.suggest_volume(team, usage.last_cycle.total)

    for recipient <- team.owners ++ team.billing_members do
      recipient
      |> PlausibleWeb.Email.dashboard_locked(team, usage, suggested_volume)
      |> Plausible.Mailer.send()
    end
  end

  defp send_grace_period_end_email(_team, false), do: :ok
end
