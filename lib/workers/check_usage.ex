defmodule Plausible.Workers.CheckUsage do
  use Plausible.Repo
  use Oban.Worker, queue: :check_usage

  @impl Oban.Worker
  def perform(_args, _job, billing_mod \\ Plausible.Billing) do
    active_subscribers =
      Repo.all(
        from u in Plausible.Auth.User,
          join: s in Plausible.Billing.Subscription,
          on: s.user_id == u.id,
          where: s.status == "active",
          preload: [subscription: s]
      )

    for subscriber <- active_subscribers do
      allowance = Plausible.Billing.Plans.allowance(subscriber.subscription)
      {last_last_month, last_month} = billing_mod.last_two_billing_months_usage(subscriber)

      if last_last_month > allowance && last_month > allowance do
        template = PlausibleWeb.Email.over_limit_email(subscriber, last_month)
        Plausible.Mailer.send_email(template)
      end
    end

    :ok
  end
end
