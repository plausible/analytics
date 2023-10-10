defmodule Plausible.Workers.CheckUsage do
  use Plausible.Repo
  use Oban.Worker, queue: :check_usage
  require Plausible.Billing.Subscription.Status
  alias Plausible.Billing.Subscription

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
  def perform(_job, billing_mod \\ Plausible.Billing, today \\ Timex.today()) do
    yesterday = today |> Timex.shift(days: -1)

    active_subscribers =
      Repo.all(
        from(u in Plausible.Auth.User,
          join: s in Plausible.Billing.Subscription,
          on: s.user_id == u.id,
          left_join: ep in Plausible.Billing.EnterprisePlan,
          on: ep.user_id == u.id,
          where: is_nil(u.grace_period),
          where: s.status == ^Subscription.Status.active(),
          where: not is_nil(s.last_bill_date),
          # Accounts for situations like last_bill_date==2021-01-31 AND today==2021-03-01. Since February never reaches the 31st day, the account is checked on 2021-03-01.
          where:
            least(day_of_month(s.last_bill_date), day_of_month(last_day_of_month(^yesterday))) ==
              day_of_month(^yesterday),
          preload: [subscription: s, enterprise_plan: ep]
        )
      )

    for subscriber <- active_subscribers do
      if subscriber.enterprise_plan do
        check_enterprise_subscriber(subscriber, billing_mod)
      else
        check_regular_subscriber(subscriber, billing_mod)
      end
    end

    :ok
  end

  def check_enterprise_subscriber(subscriber, billing_mod) do
    pageview_limit = check_pageview_limit(subscriber, billing_mod)
    site_limit = check_site_limit_for_enterprise(subscriber)

    case {pageview_limit, site_limit} do
      {{:within_limit, _}, {:within_limit, _}} ->
        nil

      {{_, {last_cycle, last_cycle_usage}}, {_, {site_usage, site_allowance}}} ->
        template =
          PlausibleWeb.Email.enterprise_over_limit_internal_email(
            subscriber,
            last_cycle_usage,
            last_cycle,
            site_usage,
            site_allowance
          )

        Plausible.Mailer.send(template)

        subscriber
        |> Plausible.Auth.GracePeriod.start_manual_lock_changeset(last_cycle_usage)
        |> Repo.update()
    end
  end

  defp check_regular_subscriber(subscriber, billing_mod) do
    case check_pageview_limit(subscriber, billing_mod) do
      {:over_limit, {last_cycle, last_cycle_usage}} ->
        suggested_plan = Plausible.Billing.Plans.suggest(subscriber, last_cycle_usage)

        template =
          PlausibleWeb.Email.over_limit_email(
            subscriber,
            last_cycle_usage,
            last_cycle,
            suggested_plan
          )

        Plausible.Mailer.send(template)

        subscriber
        |> Plausible.Auth.GracePeriod.start_changeset(last_cycle_usage)
        |> Repo.update()

      _ ->
        nil
    end
  end

  defp check_pageview_limit(subscriber, billing_mod) do
    limit =
      subscriber.subscription
      |> Plausible.Billing.Quota.monthly_pageview_limit()
      |> Kernel.*(1.1)
      |> ceil()

    {_, last_cycle} = billing_mod.last_two_billing_cycles(subscriber)

    {last_last_cycle_usage, last_cycle_usage} =
      billing_mod.last_two_billing_months_usage(subscriber)

    exceeded_last_cycle? = not Plausible.Billing.Quota.within_limit?(last_cycle_usage, limit)

    exceeded_last_last_cycle? =
      not Plausible.Billing.Quota.within_limit?(last_last_cycle_usage, limit)

    if exceeded_last_last_cycle? && exceeded_last_cycle? do
      {:over_limit, {last_cycle, last_cycle_usage}}
    else
      {:within_limit, {last_cycle, last_cycle_usage}}
    end
  end

  defp check_site_limit_for_enterprise(subscriber) do
    limit = subscriber.enterprise_plan.site_limit
    usage = Plausible.Billing.Quota.site_usage(subscriber)

    if Plausible.Billing.Quota.within_limit?(usage, limit) do
      {:within_limit, {usage, limit}}
    else
      {:over_limit, {usage, limit}}
    end
  end
end
