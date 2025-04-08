defmodule Plausible.Workers.NotifyAnnualRenewal do
  use Plausible.Repo
  use Oban.Worker, queue: :notify_annual_renewal

  require Plausible.Billing.Subscription.Status

  alias Money.Subscription
  alias Plausible.Billing.Subscription
  alias Plausible.Teams

  @yearly_plans Plausible.Billing.Plans.yearly_product_ids()

  @impl Oban.Worker
  @doc """
  Sends a notification at most 7 days and at least 1 day before the renewal of an annual subscription
  """
  def perform(_job) do
    sent_notification =
      from(
        s in "sent_renewal_notifications",
        where: s.timestamp > fragment("now() - INTERVAL '1 month'")
      )

    teams =
      Repo.all(
        from t in Teams.Team,
          as: :team,
          inner_join: o in assoc(t, :owners),
          left_join: bm in assoc(t, :billing_members),
          inner_lateral_join: s in subquery(Teams.last_subscription_join_query()),
          on: true,
          left_join: sent in ^sent_notification,
          on: o.id == sent.user_id,
          where: is_nil(sent.id),
          where: s.paddle_plan_id in @yearly_plans,
          where:
            s.next_bill_date > fragment("now()::date") and
              s.next_bill_date <= fragment("now()::date + INTERVAL '7 days'"),
          preload: [owners: o, subscription: s, billing_members: bm]
      )

    for team <- teams do
      recipients = team.owners ++ team.billing_members

      case team.subscription.status do
        Subscription.Status.active() ->
          for recipient <- recipients do
            template = PlausibleWeb.Email.yearly_renewal_notification(team, recipient)
            Plausible.Mailer.send(template)
          end

        Subscription.Status.deleted() ->
          for recipient <- recipients do
            template = PlausibleWeb.Email.yearly_expiration_notification(team, recipient)
            Plausible.Mailer.send(template)
          end

        _ ->
          Sentry.capture_message("Invalid subscription for renewal",
            team: team
          )
      end

      for recipient <- recipients do
        Repo.insert_all("sent_renewal_notifications", [
          %{
            user_id: recipient.id,
            timestamp: NaiveDateTime.utc_now()
          }
        ])
      end
    end

    :ok
  end
end
