defmodule Plausible.Billing do
  use Plausible
  use Plausible.Repo
  require Plausible.Billing.Subscription.Status
  alias Plausible.Auth
  alias Plausible.Billing.Subscription
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

  def change_plan_preview(subscription, new_plan_id) do
    case paddle_api().update_subscription_preview(
           subscription.paddle_subscription_id,
           new_plan_id
         ) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_subscription_created(params) do
    team = get_team!(params)

    subscription_params =
      params
      |> format_subscription()
      |> add_last_bill_date(params)

    team
    |> Subscription.create_changeset(subscription_params)
    |> Repo.insert!()
    |> after_subscription_update()
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
      params = format_subscription(params)

      subscription
      |> Subscription.changeset(params)
      |> Repo.update!()
      |> after_subscription_update()
    end
  end

  defp handle_subscription_cancelled(params) do
    subscription =
      Subscription
      |> Repo.get_by(paddle_subscription_id: params["subscription_id"])
      |> Repo.preload(team: :owner)

    if subscription do
      changeset =
        Subscription.changeset(subscription, %{
          status: params["status"]
        })

      updated = Repo.update!(changeset)

      subscription.team.owner
      |> PlausibleWeb.Email.cancellation_email()
      |> Plausible.Mailer.send()

      updated
    end
  end

  defp handle_subscription_payment_succeeded(params) do
    subscription = Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])

    if subscription do
      {:ok, api_subscription} = paddle_api().get_subscription(subscription.paddle_subscription_id)

      amount =
        :erlang.float_to_binary(api_subscription["next_payment"]["amount"] / 1, decimals: 2)

      subscription =
        subscription
        |> Subscription.changeset(%{
          next_bill_amount: amount,
          next_bill_date: api_subscription["next_payment"]["date"],
          last_bill_date: api_subscription["last_payment"]["date"]
        })
        |> Repo.update!()
        |> Repo.preload(:team)

      Plausible.Teams.update_accept_traffic_until(subscription.team)

      subscription
    end
  end

  defp get_team!(%{"passthrough" => passthrough}) do
    case parse_passthrough!(passthrough) do
      {:team_id, team_id} ->
        Teams.get!(team_id)

      {:user_id, user_id} ->
        user = Repo.get!(Auth.User, user_id)
        {:ok, team} = Teams.get_or_create(user)
        team
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

        # NOTE: legacy pattern, to be removed in a follow-up
        ["user:" <> user_id, "team:" <> team_id] ->
          {user_id, team_id}

        # NOTE: legacy pattern, to be removed in a follow-up
        [user_id] ->
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

  @spec format_price(Money.t()) :: String.t()
  def format_price(money) do
    Money.to_string!(money, fractional_digits: 2, no_fraction_if_integer: true)
  end

  def paddle_api(), do: Application.fetch_env!(:plausible, :paddle_api)

  def cancelled_subscription_notice_dismiss_id(id) do
    "subscription_cancelled__#{id}"
  end

  defp after_subscription_update(subscription) do
    team =
      Teams.Team
      |> Repo.get!(subscription.team_id)
      |> Teams.with_subscription()
      |> Repo.preload(:owner)

    if subscription.id != team.subscription.id do
      Sentry.capture_message("Susbscription ID mismatch",
        extra: %{subscription: inspect(subscription), team_id: team.id}
      )
    end

    team
    |> Plausible.Teams.update_accept_traffic_until()
    |> Plausible.Teams.remove_grace_period()
    |> Plausible.Teams.maybe_reset_next_upgrade_override()
    |> tap(&Plausible.Billing.SiteLocker.update_sites_for/1)
    |> maybe_adjust_api_key_limits()
  end

  defp maybe_adjust_api_key_limits(team) do
    plan =
      Repo.get_by(Plausible.Billing.EnterprisePlan,
        team_id: team.id,
        paddle_plan_id: team.subscription.paddle_plan_id
      )

    if plan do
      api_keys = from(key in Plausible.Auth.ApiKey, where: key.user_id == ^team.owner.id)
      Repo.update_all(api_keys, set: [hourly_request_limit: plan.hourly_api_request_limit])
    end

    team
  end
end
