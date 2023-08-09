defmodule Plausible.Workers.NotifyAnnualRenewal do
  use Plausible.Repo
  use Oban.Worker, queue: :notify_annual_renewal

  @yearly_plans Plausible.Billing.Plans.yearly_product_ids()

  @impl Oban.Worker
  @doc """
  Sends a notification at most 7 days and at least 1 day before the renewal of an annual subscription
  """
  def perform(_job) do
    current_subscriptions =
      from(
        s in Plausible.Billing.Subscription,
        group_by: s.user_id,
        select: %{
          user_id: s.user_id,
          inserted_at: max(s.inserted_at)
        }
      )

    sent_notification =
      from(
        s in "sent_renewal_notifications",
        where: s.timestamp > fragment("now() - INTERVAL '1 month'")
      )

    users =
      Repo.all(
        from u in Plausible.Auth.User,
          join: cs in subquery(current_subscriptions),
          on: cs.user_id == u.id,
          join: s in Plausible.Billing.Subscription,
          on: s.inserted_at == cs.inserted_at,
          left_join: sent in ^sent_notification,
          on: s.user_id == sent.user_id,
          where: is_nil(sent.id),
          where: s.paddle_plan_id in @yearly_plans,
          where:
            s.next_bill_date > fragment("now()::date") and
              s.next_bill_date <= fragment("now()::date + INTERVAL '7 days'"),
          preload: [subscription: s]
      )

    for user <- users do
      case user.subscription.status do
        "active" ->
          template = PlausibleWeb.Email.yearly_renewal_notification(user)
          Plausible.Mailer.send(template)

        "deleted" ->
          template = PlausibleWeb.Email.yearly_expiration_notification(user)
          Plausible.Mailer.send(template)

        _ ->
          Sentry.capture_message("Invalid subscription for renewal", user: user)
      end

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
