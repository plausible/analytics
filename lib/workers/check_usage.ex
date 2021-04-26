defmodule Plausible.Workers.CheckUsage do
  use Plausible.Repo
  use Oban.Worker, queue: :check_usage

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
        from u in Plausible.Auth.User,
          join: s in Plausible.Billing.Subscription,
          on: s.user_id == u.id,
          where: s.status == "active",
          where: not is_nil(s.last_bill_date),
          # Accounts for situations like last_bill_date==2021-01-31 AND today==2021-03-01. Since February never reaches the 31st day, the account is checked on 2021-03-01.
          where:
            least(day_of_month(s.last_bill_date), day_of_month(last_day_of_month(^yesterday))) ==
              day_of_month(^yesterday),
          preload: [subscription: s]
      )

    for subscriber <- active_subscribers do
      allowance = Plausible.Billing.Plans.allowance(subscriber.subscription)
      {last_last_month, last_month} = billing_mod.last_two_billing_months_usage(subscriber)

      if last_last_month > allowance && last_month > allowance do
        {_, last_cycle} = billing_mod.last_two_billing_cycles(subscriber)
        template = PlausibleWeb.Email.over_limit_email(subscriber, last_month, last_cycle)
        Plausible.Mailer.send_email(template)
      end
    end

    :ok
  end
end
