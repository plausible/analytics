defmodule Plausible.Auth.GracePeriod do
  @moduledoc """
  This embedded schema stores information about the account locking grace
  period.

  Users are given this 7-day grace period to upgrade their account after
  outgrowing their subscriptions. The actual account locking happens in
  background with `Plausible.Workers.LockSites`.

  The grace period can also be manual, without an end date, being controlled
  manually from the CRM, and not by the background site locker job. This is
  useful for enterprise subscriptions.
  """

  use Ecto.Schema
  alias Plausible.Auth.User

  @type t() :: %__MODULE__{
          end_date: Date.t() | nil,
          is_over: boolean(),
          manual_lock: boolean()
        }

  embedded_schema do
    field :end_date, :date
    field :is_over, :boolean
    field :manual_lock, :boolean
  end

  @spec start_changeset(User.t()) :: Ecto.Changeset.t()
  @doc """
  Starts a account locking grace period of 7 days by changing the User struct.
  """
  def start_changeset(%User{} = user) do
    grace_period = %__MODULE__{
      end_date: Date.shift(Date.utc_today(), day: 7),
      is_over: false,
      manual_lock: false
    }

    Ecto.Changeset.change(user, grace_period: grace_period)
  end

  @spec start_manual_lock_changeset(User.t()) :: Ecto.Changeset.t()
  @doc """
  Starts a manual account locking grace period by changing the User struct.
  Manual locking means the grace period can only be removed manually from the
  CRM.
  """
  def start_manual_lock_changeset(%User{} = user) do
    grace_period = %__MODULE__{
      end_date: nil,
      is_over: false,
      manual_lock: true
    }

    Ecto.Changeset.change(user, grace_period: grace_period)
  end

  @spec end_changeset(User.t()) :: Ecto.Changeset.t()
  @doc """
  Ends an existing grace period by `setting users.grace_period.is_over` to true.
  This means the grace period has expired.
  """
  def end_changeset(%User{} = user) do
    Ecto.Changeset.change(user, grace_period: %{is_over: true})
  end

  @spec remove_changeset(User.t()) :: Ecto.Changeset.t()
  @doc """
  Removes the grace period from the User completely.
  """
  def remove_changeset(%User{} = user) do
    Ecto.Changeset.change(user, grace_period: nil)
  end

  @spec active?(User.t() | Plausible.Teams.Team.t()) :: boolean()
  @doc """
  Returns whether the grace period is still active for a User. Defaults to
  false if the user is nil or there is no grace period.
  """
  def active?(user_or_team)

  def active?(%{grace_period: %__MODULE__{end_date: %Date{} = end_date}}) do
    Date.diff(end_date, Date.utc_today()) >= 0
  end

  def active?(%{grace_period: %__MODULE__{manual_lock: true}}) do
    true
  end

  def active?(_user), do: false

  @spec expired?(User.t() | Plausible.Teams.Team.t() | nil) :: boolean()
  @doc """
  Returns whether the grace period has already expired for a User. Defaults to
  false if the user is nil or there is no grace period.
  """
  def expired?(user_or_team) do
    if user_or_team && user_or_team.grace_period, do: !active?(user_or_team), else: false
  end
end
