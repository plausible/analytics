defmodule Plausible.Billing.PaddleClassic.Webhooks do
  @moduledoc """
  Handles Paddle Classic webhook alerts: parses the payloads into subscription
  attributes and hands them to `Plausible.Billing.SubscriptionState`.

  To be deleted after the Paddle Billing migration.
  """
  use Plausible.Repo

  alias Plausible.Auth
  alias Plausible.Billing.{PaddleClassic, Subscription, SubscriptionState}
  alias Plausible.Teams

  def subscription_created(params) do
    Repo.transaction(fn ->
      handle_subscription_created(params)
    end)
  end

  def subscription_updated(params) do
    Repo.transaction(fn ->
      handle_subscription_updated(params)
    end)
  end

  def subscription_cancelled(params) do
    Repo.transaction(fn ->
      handle_subscription_cancelled(params)
    end)
  end

  def subscription_payment_succeeded(params) do
    Repo.transaction(fn ->
      handle_subscription_payment_succeeded(params)
    end)
  end

  defp handle_subscription_created(params) do
    team = get_team!(params)

    subscription_params =
      params
      |> format_subscription()
      |> add_last_bill_date(params)

    SubscriptionState.create(team, subscription_params)
  end

  defp handle_subscription_updated(params) do
    subscription = Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])

    # In a situation where the subscription is paused and a payment succeeds, we
    # get notified of two "subscription_updated" webhook alerts from Paddle at the
    # same time.
    #
    #   * one with an `old_status` of "paused", and a `status` of "past_due"
    #   * the other with an `old_status` of "past_due", and a `status` of "active"
    #
    # https://developer.paddle.com/classic/guides/zg9joji1mzu0mduy-payment-failures
    #
    # Relying on the time when the webhooks are sent has caused issues where
    # subscriptions have ended up `past_due` after a successful payment. Therefore,
    # we're now explicitly ignoring the first webhook (with the update that's not
    # relevant to us).
    irrelevant? = params["old_status"] == "paused" && params["status"] == "past_due"

    if subscription && not irrelevant? do
      SubscriptionState.update(subscription, format_subscription(params))
    end
  end

  defp handle_subscription_cancelled(params) do
    subscription = Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])

    if subscription do
      SubscriptionState.cancel(subscription, %{status: params["status"]})
    end
  end

  defp handle_subscription_payment_succeeded(params) do
    subscription = Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])

    if subscription do
      {:ok, api_subscription} =
        PaddleClassic.api().get_subscription(subscription.paddle_subscription_id)

      amount =
        :erlang.float_to_binary(api_subscription["next_payment"]["amount"] / 1, decimals: 2)

      SubscriptionState.record_payment(subscription, %{
        next_bill_amount: amount,
        next_bill_date: api_subscription["next_payment"]["date"],
        last_bill_date: api_subscription["last_payment"]["date"]
      })
    end
  end

  defp get_team!(%{"passthrough" => passthrough}) do
    case parse_passthrough!(passthrough) do
      {:team_id, team_id} ->
        Teams.get!(team_id)

      {:user_id, user_id} ->
        # Given a guest or non-owner member user initiates the new subscription payment
        # and becomes an owner of an existing team already with a subscription in between,
        # this could result in assigning this new subscription to the newly owned team,
        # effectively "shadowing" any old one.
        #
        # That's why we are always defaulting to creating a new "My Personal Sites" team regardless
        # if they were owner of one before or not.
        Auth.User
        |> Repo.get!(user_id)
        |> Teams.force_create_my_team()
    end
  end

  defp get_team!(_params) do
    raise "Missing passthrough"
  end

  defp parse_passthrough!(passthrough) do
    {user_id, team_id} =
      case String.split(to_string(passthrough), ";") do
        ["ee:true", "user:" <> user_id, "team:" <> team_id] ->
          {user_id, team_id}

        ["ee:true", "user:" <> user_id] ->
          {user_id, "0"}

        _ ->
          raise "Invalid passthrough sent via Paddle: #{inspect(passthrough)}"
      end

    case {Integer.parse(user_id), Integer.parse(team_id)} do
      {{user_id, ""}, {0, ""}} when user_id > 0 ->
        {:user_id, user_id}

      {{_user_id, ""}, {team_id, ""}} when team_id > 0 ->
        {:team_id, team_id}

      _ ->
        raise "Invalid passthrough sent via Paddle: #{inspect(passthrough)}"
    end
  end

  defp format_subscription(params) do
    %{
      paddle_subscription_id: params["subscription_id"],
      paddle_plan_id: params["subscription_plan_id"],
      cancel_url: params["cancel_url"],
      update_url: params["update_url"],
      status: params["status"],
      next_bill_date: params["next_bill_date"],
      next_bill_amount: params["unit_price"] || params["new_unit_price"],
      currency_code: params["currency"]
    }
  end

  defp add_last_bill_date(subscription_params, paddle_params) do
    with datetime_str when is_binary(datetime_str) <- paddle_params["event_time"],
         {:ok, datetime} <- NaiveDateTime.from_iso8601(datetime_str),
         date <- NaiveDateTime.to_date(datetime) do
      Map.put(subscription_params, :last_bill_date, date)
    else
      _ -> subscription_params
    end
  end
end
