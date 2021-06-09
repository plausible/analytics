defmodule Plausible.Billing do
  use Plausible.Repo
  alias Plausible.Billing.{Subscription, PaddleApi}
  use Plausible.ClickhouseRepo

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
  end

  def subscription_updated(params) do
    subscription = Repo.get_by!(Subscription, paddle_subscription_id: params["subscription_id"])
    changeset = Subscription.changeset(subscription, format_subscription(params))

    Repo.update(changeset)
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

  def needs_to_upgrade?(user) do
    if Timex.before?(user.trial_expiry_date, Timex.today()) do
      !subscription_is_active?(user.subscription)
    else
      false
    end
  end

  defp subscription_is_active?(%Subscription{status: "active"}), do: true
  defp subscription_is_active?(%Subscription{status: "past_due"}), do: true

  defp subscription_is_active?(%Subscription{status: "deleted"} = subscription) do
    subscription.next_bill_date && !Timex.before?(subscription.next_bill_date, Timex.today())
  end

  defp subscription_is_active?(%Subscription{}), do: false
  defp subscription_is_active?(nil), do: false

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

  defp get_usage_for_billing_cycle(sites, cycle) do
    domains = Enum.map(sites, & &1.domain)

    ClickhouseRepo.one(
      from e in "events",
        where: e.domain in ^domains,
        where: fragment("toDate(?)", e.timestamp) >= ^cycle.first,
        where: fragment("toDate(?)", e.timestamp) <= ^cycle.last,
        select: fragment("count(*)")
    )
  end

  def last_two_billing_months_usage(user, today \\ Timex.today()) do
    {first, second} = last_two_billing_cycles(user, today)
    sites = Plausible.Sites.owned_by(user)

    {
      get_usage_for_billing_cycle(sites, first),
      get_usage_for_billing_cycle(sites, second)
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
    sites = Plausible.Sites.owned_by(user)

    Enum.reduce(sites, {0, 0}, fn site, {pageviews, custom_events} ->
      usage = Plausible.Stats.Clickhouse.usage(site)

      {pageviews + Map.get(usage, "pageviews", 0),
       custom_events + Map.get(usage, "custom_events", 0)}
    end)
  end

  @doc """
  Returns the number of sites that an account is allowed to have. Accounts for
  grandfathering old accounts to unlimited websites and ignores site limit on self-hosted
  installations.
  """
  @limit_accounts_since ~D[2021-05-05]
  def sites_limit(user) do
    cond do
      Timex.before?(user.inserted_at, @limit_accounts_since) -> nil
      Application.get_env(:plausible, :is_selfhost) -> nil
      user.email in Application.get_env(:plausible, :site_limit_exempt) -> nil
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

  defp paddle_api(), do: Application.fetch_env!(:plausible, :paddle_api)
end
