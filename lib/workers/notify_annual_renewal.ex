defmodule Plausible.Workers.NotifyAnnualRenewal do
  use Plausible.Repo
  use Oban.Worker, queue: :check_usage

  @yearly_plans Plausible.Billing.Plans.yearly_plan_ids()

  @impl Oban.Worker
  @doc """
  Sends a notification at most 7 days and at least 1 day before the renewal of an annual subscription
  """
  def perform(_args, _job, today \\ Timex.today()) do
    latest = Timex.shift(today, days: 7, years: -1)
    earliest = Timex.shift(today, days: 1, years: -1)

    users =
      Repo.all(
        from u in Plausible.Auth.User,
          left_join: sent in "sent_renewal_notifications",
          join: s in Plausible.Billing.Subscription,
          on: s.user_id == u.id,
          where: s.paddle_plan_id in @yearly_plans,
          where: s.last_bill_date <= ^latest and s.last_bill_date >= ^earliest,
          where: is_nil(sent.id) or sent.timestamp < fragment("now() - INTERVAL '1 month'"),
          preload: [subscription: s]
      )

    for user <- users do
      renewal_date = Timex.shift(user.subscription.last_bill_date, years: 1)
      template = PlausibleWeb.Email.yearly_renewal_notification(user, renewal_date)
      Plausible.Mailer.send_email(template)

      Repo.insert_all("sent_renewal_notifications", [
        %{
          user_id: user.id,
          timestamp: NaiveDateTime.utc_now()
        }
      ])
    end

    :ok
  end
end
