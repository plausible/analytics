defmodule Plausible.Users do
  @moduledoc """
  User context
  """
  use Plausible

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Auth.GracePeriod
  alias Plausible.Billing.Subscription
  alias Plausible.Repo

  @spec trial_days_left(Auth.User.t()) :: integer()
  def trial_days_left(user) do
    Date.diff(user.trial_expiry_date, Date.utc_today())
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

    Plausible.Teams.sync_team(user)

    user
  end

  def allow_next_upgrade_override(%Auth.User{} = user) do
    user =
      user
      |> Auth.User.changeset(%{allow_next_upgrade_override: true})
      |> Repo.update!()

    Plausible.Teams.sync_team(user)

    user
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

    Plausible.Teams.sync_team(user)

    user
  end

  def start_manual_lock_grace_period(user) do
    user =
      user
      |> GracePeriod.start_manual_lock_changeset()
      |> Repo.update!()

    Plausible.Teams.sync_team(user)

    user
  end

  def end_grace_period(user) do
    user =
      user
      |> GracePeriod.end_changeset()
      |> Repo.update!()

    Plausible.Teams.sync_team(user)

    user
  end

  def remove_grace_period(user) do
    user =
      user
      |> GracePeriod.remove_changeset()
      |> Repo.update!()

    Plausible.Teams.sync_team(user)

    user
  end

  def last_subscription_query() do
    from(subscription in Subscription,
      order_by: [desc: subscription.inserted_at],
      limit: 1
    )
  end
end
