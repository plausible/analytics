defmodule Plausible.Billing.Subscriptions do
  @moduledoc false

  require Plausible.Billing.Subscription.Status

  import Ecto.Query

  alias Plausible.Billing.PaddleBilling
  alias Plausible.Billing.PaddleClassic
  alias Plausible.Billing.Subscription

  def active?(%Subscription{status: Subscription.Status.active()}), do: true
  def active?(%Subscription{status: Subscription.Status.past_due()}), do: true

  def active?(%Subscription{status: Subscription.Status.deleted()} = subscription) do
    not is_nil(subscription.next_bill_date) and
      not Date.before?(subscription.next_bill_date, Date.utc_today())
  end

  def active?(%Subscription{}), do: false
  def active?(nil), do: false

  @spec expired?(Subscription.t()) :: boolean()
  @doc """
  Returns whether the given subscription is expired. That means that the
  subscription status is `deleted` and the date until which the customer
  has paid for (i.e. `next_bill_date`) has passed.
  """
  def expired?(subscription)

  def expired?(%Subscription{paddle_plan_id: "free_10k"}), do: false

  def expired?(%Subscription{next_bill_date: next_bill_date} = subscription) do
    deleted? = Subscription.Status.deleted?(subscription)
    expired? = Date.before?(next_bill_date, Date.utc_today())

    deleted? && expired?
  end

  def resumable?(subscription) do
    Subscription.Status.in?(subscription, [
      Subscription.Status.active(),
      Subscription.Status.past_due(),
      Subscription.Status.paused()
    ])
  end

  def halted?(subscription) do
    Subscription.Status.in?(subscription, [
      Subscription.Status.past_due(),
      Subscription.Status.paused()
    ])
  end

  @spec last_subscription_join_query() :: Ecto.Query.t()
  def last_subscription_join_query() do
    from(s in last_subscription_query())
  end

  @spec last_subscription_query(:field | :value, nil | pos_integer()) :: Ecto.Query.t()
  def last_subscription_query(team_filter \\ :field, value \\ nil) do
    billing_query =
      from(
        bs in PaddleBilling.Subscription,
        select: %Subscription{
          type: "billing",
          id: bs.id,
          billing_subscription_id: bs.billing_subscription_id,
          billing_customer_id: bs.billing_customer_id,
          billing_product_id: bs.billing_product_id,
          billing_price_id: bs.billing_price_id,
          next_bill_amount: bs.next_bill_amount,
          next_bill_date: bs.next_bill_date,
          last_bill_date: bs.last_bill_date,
          currency_code: bs.currency_code,
          status:
            fragment("CASE WHEN ? = 'canceled' THEN 'deleted' ELSE ? END", bs.status, bs.status),
          team_id: bs.team_id,
          inserted_at: bs.inserted_at
        }
      )
      |> apply_filter(team_filter, value)

    classic_query =
      from(cs in PaddleClassic.Subscription,
        limit: 1,
        select: %Subscription{
          type: "classic",
          id: cs.id,
          paddle_subscription_id: cs.paddle_subscription_id,
          paddle_plan_id: cs.paddle_plan_id,
          update_url: cs.update_url,
          cancel_url: cs.cancel_url,
          next_bill_amount: cs.next_bill_amount,
          next_bill_date: cs.next_bill_date,
          last_bill_date: cs.last_bill_date,
          currency_code: cs.currency_code,
          status: cs.status,
          team_id: cs.team_id,
          inserted_at: cs.inserted_at
        }
      )
      |> apply_filter(team_filter, value)

    union =
      classic_query
      |> union_all(^billing_query)

    from(s in subquery(union))
    |> order_by([s], desc: s.inserted_at, desc: s.id)
    |> limit(1)
  end

  defp apply_filter(query, :field, _) do
    from s in query, where: s.team_id == parent_as(:team).id
  end

  defp apply_filter(query, :value, value) do
    from s in query, where: s.team_id == ^value
  end
end
