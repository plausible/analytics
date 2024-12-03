defmodule Plausible.Workers.CheckUsage do
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
          inner_join: o in assoc(t, :owner),
          inner_lateral_join: s in subquery(Teams.last_subscription_join_query()),
          on: true,
          left_join: ep in assoc(t, :enterprise_plan),
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
          preload: [subscription: s, enterprise_plan: ep, owner: o]
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

  defp check_site_usage_for_enterprise(subscriber) do
    limit = subscriber.enterprise_plan.site_limit

    usage = Teams.Billing.site_usage(subscriber)

    if Quota.below_limit?(usage, limit) do
      {:below_limit, {usage, limit}}
    else
      {:over_limit, {usage, limit}}
    end
  end

  def maybe_remove_grace_period(subscriber, usage_mod) do
    case check_pageview_usage_last_cycle(subscriber, usage_mod) do
      {:below_limit, _} ->
        Plausible.Users.remove_grace_period(subscriber.owner)
        :ok

      _ ->
        :skip
    end
  end

  defp check_regular_subscriber(subscriber, usage_mod) do
    case check_pageview_usage_two_cycles(subscriber, usage_mod) do
      {:over_limit, pageview_usage} ->
        suggested_plan =
          Plausible.Billing.Plans.suggest(subscriber, pageview_usage.last_cycle.total)

        PlausibleWeb.Email.over_limit_email(subscriber.owner, pageview_usage, suggested_plan)
        |> Plausible.Mailer.send()

        Plausible.Users.start_grace_period(subscriber.owner)

      _ ->
        nil
    end
  end

  def check_enterprise_subscriber(subscriber, usage_mod) do
    pageview_usage = check_pageview_usage_two_cycles(subscriber, usage_mod)
    site_usage = check_site_usage_for_enterprise(subscriber)

    case {pageview_usage, site_usage} do
      {{:below_limit, _}, {:below_limit, _}} ->
        nil

      {{_, pageview_usage}, {_, {site_usage, site_allowance}}} ->
        PlausibleWeb.Email.enterprise_over_limit_internal_email(
          subscriber.owner,
          pageview_usage,
          site_usage,
          site_allowance
        )
        |> Plausible.Mailer.send()

        Plausible.Users.start_manual_lock_grace_period(subscriber.owner)
    end
  end

  defp check_pageview_usage_two_cycles(subscriber, usage_mod) do
    usage = usage_mod.monthly_pageview_usage(subscriber)
    limit = Teams.Billing.monthly_pageview_limit(subscriber.subscription)

    if Quota.exceeds_last_two_usage_cycles?(usage, limit) do
      {:over_limit, usage}
    else
      {:below_limit, usage}
    end
  end

  defp check_pageview_usage_last_cycle(subscriber, usage_mod) do
    usage = usage_mod.monthly_pageview_usage(subscriber)
    limit = Teams.Billing.monthly_pageview_limit(subscriber.subscription)

    if :last_cycle in Quota.exceeded_cycles(usage, limit) do
      {:over_limit, usage}
    else
      {:below_limit, usage}
    end
  end
end
