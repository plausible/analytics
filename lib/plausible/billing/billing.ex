defmodule Plausible.Billing do
  use Plausible.Repo
  alias Plausible.Billing.{Subscription, PaddleApi}

  def active_subscription_for(user_id) do
    Repo.get_by(Subscription, user_id: user_id, status: "active")
  end

  def subscription_created(params) do
    params =
      if present?(params["passthrough"]) do
        params
      else
        user = Repo.get_by(Plausible.Auth.User, email: params["email"])
        Map.put(params, "passthrough", user && user.id)
      end

    changeset = Subscription.changeset(%Subscription{}, format_subscription(params))

    Repo.insert(changeset)
    |> check_lock_status
    |> maybe_adjust_api_key_limits
  end

  def subscription_updated(params) do
    subscription = Repo.get_by!(Subscription, paddle_subscription_id: params["subscription_id"])
    changeset = Subscription.changeset(subscription, format_subscription(params))

    Repo.update(changeset)
    |> check_lock_status
    |> maybe_adjust_api_key_limits
  end

  def subscription_cancelled(params) do
    subscription =
      Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])
      |> Repo.preload(:user)

    if subscription do
      changeset =
        Subscription.changeset(subscription, %{
          status: params["status"]
        })

      case Repo.update(changeset) do
        {:ok, updated} ->
          PlausibleWeb.Email.cancellation_email(subscription.user)
          |> Plausible.Mailer.send_email()

          {:ok, updated}

        err ->
          err
      end
    else
      {:ok, nil}
    end
  end

  def subscription_payment_succeeded(params) do
    subscription = Repo.get_by(Subscription, paddle_subscription_id: params["subscription_id"])

    if subscription do
      {:ok, api_subscription} = paddle_api().get_subscription(subscription.paddle_subscription_id)

      amount =
        :erlang.float_to_binary(api_subscription["next_payment"]["amount"] / 1, decimals: 2)

      changeset =
        Subscription.changeset(subscription, %{
          next_bill_amount: amount,
          next_bill_date: api_subscription["next_payment"]["date"],
          last_bill_date: api_subscription["last_payment"]["date"]
        })

      Repo.update(changeset)
    else
      {:ok, nil}
    end
  end

  def change_plan(user, new_plan_id) do
    subscription = active_subscription_for(user.id)

    res =
      paddle_api().update_subscription(subscription.paddle_subscription_id, %{
        plan_id: new_plan_id
      })

    case res do
      {:ok, response} ->
        amount = :erlang.float_to_binary(response["next_payment"]["amount"] / 1, decimals: 2)

        Subscription.changeset(subscription, %{
          paddle_plan_id: Integer.to_string(response["plan_id"]),
          next_bill_amount: amount,
          next_bill_date: response["next_payment"]["date"]
        })
        |> Repo.update()

      e ->
        e
    end
  end

  def change_plan_preview(subscription, new_plan_id) do
    PaddleApi.update_subscription_preview(subscription.paddle_subscription_id, new_plan_id)
  end

  def needs_to_upgrade?(%Plausible.Auth.User{trial_expiry_date: nil}), do: {true, :no_trial}

  def needs_to_upgrade?(user) do
    trial_is_over = Timex.before?(user.trial_expiry_date, Timex.today())
    subscription_active = subscription_is_active?(user.subscription)

    grace_period_ended =
      user.grace_period_end && Timex.before?(user.grace_period_end, Timex.today())

    cond do
      trial_is_over && !subscription_active -> {true, :no_active_subscription}
      grace_period_ended -> {true, :grace_period_ended}
      true -> false
    end
  end

  defp subscription_is_active?(%Subscription{status: "active"}), do: true
  defp subscription_is_active?(%Subscription{status: "past_due"}), do: true

  defp subscription_is_active?(%Subscription{status: "deleted"} = subscription) do
    subscription.next_bill_date && !Timex.before?(subscription.next_bill_date, Timex.today())
  end

  defp subscription_is_active?(%Subscription{}), do: false
  defp subscription_is_active?(nil), do: false

  def on_trial?(%Plausible.Auth.User{trial_expiry_date: nil}), do: false

  def on_trial?(user) do
    !subscription_is_active?(user.subscription) && trial_days_left(user) >= 0
  end

  def trial_days_left(user) do
    Timex.diff(user.trial_expiry_date, Timex.today(), :days)
  end

  def usage(user) do
    {pageviews, custom_events} = usage_breakdown(user)
    pageviews + custom_events
  end

  def last_two_billing_months_usage(user, today \\ Timex.today()) do
    {first, second} = last_two_billing_cycles(user, today)
    sites = Plausible.Sites.owned_by(user)

    usage_for_sites = fn sites, date_range ->
      domains = Enum.map(sites, & &1.domain)
      {pageviews, custom_events} = Plausible.Stats.Clickhouse.usage_breakdown(domains, date_range)
      pageviews + custom_events
    end

    {
      usage_for_sites.(sites, first),
      usage_for_sites.(sites, second)
    }
  end

  def last_two_billing_cycles(user, today \\ Timex.today()) do
    last_bill_date = user.subscription.last_bill_date

    normalized_last_bill_date =
      Timex.shift(last_bill_date,
        months: Timex.diff(today, last_bill_date, :months)
      )

    {
      Date.range(
        Timex.shift(normalized_last_bill_date, months: -2),
        Timex.shift(normalized_last_bill_date, days: -1, months: -1)
      ),
      Date.range(
        Timex.shift(normalized_last_bill_date, months: -1),
        Timex.shift(normalized_last_bill_date, days: -1)
      )
    }
  end

  def usage_breakdown(user) do
    domains = Plausible.Sites.owned_by(user) |> Enum.map(& &1.domain)
    Plausible.Stats.Clickhouse.usage_breakdown(domains)
  end

  @doc """
  Returns the number of sites that an account is allowed to have. Accounts for
  grandfathering old accounts to unlimited websites and ignores site limit on self-hosted
  installations.
  """
  @limit_accounts_since ~D[2021-05-05]
  def sites_limit(user) do
    user = Plausible.Repo.preload(user, :enterprise_plan)

    cond do
      Timex.before?(user.inserted_at, @limit_accounts_since) -> nil
      Application.get_env(:plausible, :is_selfhost) -> nil
      user.email in Application.get_env(:plausible, :site_limit_exempt) -> nil
      user.enterprise_plan -> nil
      true -> Application.get_env(:plausible, :site_limit)
    end
  end

  defp format_subscription(params) do
    %{
      paddle_subscription_id: params["subscription_id"],
      paddle_plan_id: params["subscription_plan_id"],
      cancel_url: params["cancel_url"],
      update_url: params["update_url"],
      user_id: params["passthrough"],
      status: params["status"],
      next_bill_date: params["next_bill_date"],
      next_bill_amount: params["unit_price"] || params["new_unit_price"],
      currency_code: params["currency"]
    }
  end

  defp present?(""), do: false
  defp present?(nil), do: false
  defp present?(_), do: true

  defp check_lock_status({:ok, subscription}) do
    user =
      Repo.get(Plausible.Auth.User, subscription.user_id)
      |> Map.put(:subscription, subscription)

    Plausible.Billing.SiteLocker.check_sites_for(user)
    {:ok, subscription}
  end

  defp check_lock_status(err), do: err

  defp maybe_adjust_api_key_limits({:ok, subscription}) do
    plan =
      Repo.get_by(Plausible.Billing.EnterprisePlan,
        user_id: subscription.user_id,
        paddle_plan_id: subscription.paddle_plan_id
      )

    if plan do
      user_id = subscription.user_id
      api_keys = from(key in Plausible.Auth.ApiKey, where: key.user_id == ^user_id)
      Repo.update_all(api_keys, set: [hourly_request_limit: plan.hourly_api_request_limit])
    end

    {:ok, subscription}
  end

  defp maybe_adjust_api_key_limits(err), do: err

  defp paddle_api(), do: Application.fetch_env!(:plausible, :paddle_api)
end
