defmodule Plausible.Users do
  @moduledoc """
  User context
  """
  use Plausible
  @accept_traffic_until_free ~D[2135-01-01]

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Auth.GracePeriod
  alias Plausible.Billing.Subscription
  alias Plausible.Repo

  @spec on_trial?(Auth.User.t()) :: boolean()
  on_ee do
    def on_trial?(%Auth.User{trial_expiry_date: nil}), do: false

    def on_trial?(user) do
      user = with_subscription(user)
      not Plausible.Billing.Subscriptions.active?(user.subscription) && trial_days_left(user) >= 0
    end
  else
    def on_trial?(_), do: true
  end

  @spec trial_days_left(Auth.User.t()) :: integer()
  def trial_days_left(user) do
    Timex.diff(user.trial_expiry_date, Date.utc_today(), :days)
  end

  @spec update_accept_traffic_until(Auth.User.t()) :: Auth.User.t()
  def update_accept_traffic_until(user) do
    user =
      user
      |> Auth.User.changeset(%{accept_traffic_until: accept_traffic_until(user)})
      |> Repo.update!()

    with_teams do
      Plausible.Teams.sync_team(user)
    end

    user
  end

  @spec bump_last_seen(Auth.User.t() | pos_integer(), NaiveDateTime.t()) :: :ok
  def bump_last_seen(%Auth.User{id: user_id}, now) do
    bump_last_seen(user_id, now)
  end

  def bump_last_seen(user_id, now) do
    q = from(u in Auth.User, where: u.id == ^user_id)

    Repo.update_all(q, set: [last_seen: now])

    :ok
  end

  @spec accept_traffic_until(Auth.User.t()) :: Date.t()
  on_ee do
    def accept_traffic_until(user) do
      user = with_subscription(user)

      cond do
        Plausible.Users.on_trial?(user) ->
          Date.shift(user.trial_expiry_date,
            day: Auth.User.trial_accept_traffic_until_offset_days()
          )

        user.subscription && user.subscription.paddle_plan_id == "free_10k" ->
          @accept_traffic_until_free

        user.subscription && user.subscription.next_bill_date ->
          Date.shift(user.subscription.next_bill_date,
            day: Auth.User.subscription_accept_traffic_until_offset_days()
          )

        true ->
          raise "This user is neither on trial or has a valid subscription. Manual intervention required."
      end
    end
  else
    def accept_traffic_until(_user) do
      @accept_traffic_until_free
    end
  end

  def with_subscription(%Auth.User{} = user) do
    Repo.preload(user, subscription: last_subscription_query())
  end

  def with_subscription(user_id) when is_integer(user_id) do
    Repo.one(
      from(user in Auth.User,
        as: :user,
        left_lateral_join: s in subquery(last_subscription_join_query()),
        on: true,
        where: user.id == ^user_id,
        preload: [subscription: s]
      )
    )
  end

  @spec has_email_code?(Auth.User.t()) :: boolean()
  def has_email_code?(user) do
    Auth.EmailVerification.any?(user)
  end

  def start_trial(%Auth.User{} = user) do
    user =
      user
      |> Auth.User.start_trial()
      |> Repo.update!()

    with_teams do
      Plausible.Teams.sync_team(user)
    end

    user
  end

  def allow_next_upgrade_override(%Auth.User{} = user) do
    user =
      user
      |> Auth.User.changeset(%{allow_next_upgrade_override: true})
      |> Repo.update!()

    with_teams do
      Plausible.Teams.sync_team(user)
    end

    user
  end

  def maybe_reset_next_upgrade_override(%Auth.User{} = user) do
    if user.allow_next_upgrade_override do
      user =
        user
        |> Auth.User.changeset(%{allow_next_upgrade_override: false})
        |> Repo.update!()

      with_teams do
        Plausible.Teams.sync_team(user)
      end

      user
    else
      user
    end
  end

  def last_subscription_join_query() do
    from(subscription in last_subscription_query(),
      where: subscription.user_id == parent_as(:user).id
    )
  end

  def start_grace_period(user) do
    user =
      user
      |> GracePeriod.start_changeset()
      |> Repo.update!()

    with_teams do
      Plausible.Teams.sync_team(user)
    end

    user
  end

  def start_manual_lock_grace_period(user) do
    user =
      user
      |> GracePeriod.start_manual_lock_changeset()
      |> Repo.update!()

    with_teams do
      Plausible.Teams.sync_team(user)
    end

    user
  end

  def end_grace_period(user) do
    user =
      user
      |> GracePeriod.end_changeset()
      |> Repo.update!()

    with_teams do
      Plausible.Teams.sync_team(user)
    end

    user
  end

  def remove_grace_period(user) do
    user =
      user
      |> GracePeriod.remove_changeset()
      |> Repo.update!()

    with_teams do
      Plausible.Teams.sync_team(user)
    end

    user
  end

  defp last_subscription_query() do
    from(subscription in Subscription,
      order_by: [desc: subscription.inserted_at],
      limit: 1
    )
  end
end
