defmodule Plausible.Workers.CheckUsage do
  @moduledoc """
  A Cron job that runs every day at 14:00, checking whether active
  subscribers have outgrown their plan limits, in which case, starts
  grace periods and notifies via email.
  """

  use Plausible.Repo
  use Oban.Worker, queue: :check_usage
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.{Subscription, Quota}
  alias Plausible.Teams

  defmacro yesterday() do
    quote do
      fragment("now() - INTERVAL '1 day'")
    end
  end

  defmacro last_day_of_month(day) do
    quote do
      fragment(
        "(date_trunc('month', ?::date) + interval '1 month' - interval '1 day')::date",
        unquote(day)
      )
    end
  end

  defmacro day_of_month(date) do
    quote do
      fragment("EXTRACT(day from ?::date)", unquote(date))
    end
  end

  defmacro least(left, right) do
    quote do
      fragment("least(?, ?)", unquote(left), unquote(right))
    end
  end

  @impl Oban.Worker
  def perform(_job, usage_mod \\ Teams.Billing, today \\ Date.utc_today()) do
    yesterday = today |> Date.shift(day: -1)

    active_subscribers =
      Repo.all(
        from(t in Teams.Team,
          as: :team,
          inner_join: o in assoc(t, :owners),
          left_join: bm in assoc(t, :billing_members),
          inner_lateral_join: s in subquery(Teams.last_subscription_join_query()),
          on: true,
          left_join: ep in Plausible.Billing.EnterprisePlan,
          on: ep.team_id == t.id and ep.paddle_plan_id == s.paddle_plan_id,
          where:
            s.status in [
              ^Subscription.Status.active(),
              ^Subscription.Status.past_due(),
              ^Subscription.Status.deleted()
            ],
          where: not is_nil(s.last_bill_date),
          # Accounts for situations like last_bill_date==2021-01-31 AND today==2021-03-01. Since February never reaches the 31st day, the account is checked on 2021-03-01.
          where: s.next_bill_date >= ^today,
          where:
            least(day_of_month(s.last_bill_date), day_of_month(last_day_of_month(^yesterday))) ==
              day_of_month(^yesterday),
          order_by: t.id,
          preload: [subscription: s, enterprise_plan: ep, owners: o, billing_members: bm]
        )
      )

    for subscriber <- active_subscribers do
      case {subscriber.grace_period, subscriber.enterprise_plan} do
        {nil, nil} ->
          check_regular_subscriber(subscriber, usage_mod)

        {nil, _} ->
          check_enterprise_subscriber(subscriber, usage_mod)

        {_, nil} ->
          maybe_remove_grace_period(subscriber, usage_mod)

        _ ->
          :skip
      end
    end

    :ok
  end

  def check_site_usage_for_enterprise(subscriber) do
    limit = Teams.Billing.site_limit(subscriber)

    usage = Teams.Billing.site_usage(subscriber)

    if Quota.within_limit?(usage, limit) do
      {:below_limit, usage, limit}
    else
      {:over_limit, usage, limit}
    end
  end

  def maybe_remove_grace_period(subscriber, usage_mod) do
    case check_pageview_usage_last_cycle(subscriber, usage_mod) do
      {:below_limit, _, _} ->
        Plausible.Teams.remove_grace_period(subscriber)
        :ok

      _ ->
        :skip
    end
  end

  defp check_regular_subscriber(subscriber, usage_mod) do
    case check_pageview_usage_two_cycles(subscriber, usage_mod) do
      {:over_limit, pageview_usage, _} ->
        suggested_volume =
          Plausible.Billing.Plans.suggest_volume(subscriber, pageview_usage.last_cycle.total)

        for owner <- subscriber.owners ++ subscriber.billing_members do
          PlausibleWeb.Email.over_limit_email(owner, subscriber, pageview_usage, suggested_volume)
          |> Plausible.Mailer.send()
        end

        Plausible.Teams.start_grace_period(subscriber)

      _ ->
        nil
    end
  end

  def check_enterprise_subscriber(subscriber, usage_mod) do
    {pageview_status, pageview_usage, pageview_limit} =
      check_pageview_usage_two_cycles(subscriber, usage_mod)

    {site_status, site_usage, site_limit} =
      check_site_usage_for_enterprise(subscriber)

    exceeds_pageview_limit? = pageview_status == :over_limit
    exceeds_site_limit? = site_status == :over_limit

    if exceeds_pageview_limit? or exceeds_site_limit? do
      team_member_emails =
        (subscriber.owners ++ subscriber.billing_members)
        |> Enum.map(& &1.email)
        |> Enum.uniq()

      PlausibleWeb.Email.enterprise_over_limit_internal_email(subscriber, %{
        team_member_emails: team_member_emails,
        exceeds_pageview_limit?: exceeds_pageview_limit?,
        pageview_usage: pageview_usage,
        pageview_limit: pageview_limit,
        exceeds_site_limit?: exceeds_site_limit?,
        site_usage: site_usage,
        site_limit: site_limit
      })
      |> Plausible.Mailer.send()

      Plausible.Teams.start_manual_lock_grace_period(subscriber)
    end
  end

  def check_pageview_usage_two_cycles(subscriber, usage_mod) do
    usage = usage_mod.monthly_pageview_usage(subscriber)
    limit = Teams.Billing.monthly_pageview_limit(subscriber.subscription)

    if Quota.exceeds_last_two_usage_cycles?(usage, limit) do
      {:over_limit, usage, limit}
    else
      {:below_limit, usage, limit}
    end
  end

  defp check_pageview_usage_last_cycle(subscriber, usage_mod) do
    usage = usage_mod.monthly_pageview_usage(subscriber)
    limit = Teams.Billing.monthly_pageview_limit(subscriber.subscription)

    if :last_cycle in Quota.exceeded_cycles(usage, limit) do
      {:over_limit, usage, limit}
    else
      {:below_limit, usage, limit}
    end
  end
end
