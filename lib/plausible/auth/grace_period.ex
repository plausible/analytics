defmodule Plausible.Auth.GracePeriod do
  @moduledoc """
  This embedded schema stores information about the account locking grace
  period.

  Users are given this 7-day grace period to upgrade their account after
  outgrowing their subscriptions. The actual account locking happens in
  background with `Plausible.Workers.LockSites`.
  """

  use Ecto.Schema
  alias Plausible.Auth.User

  @type t() :: %__MODULE__{
          end_date: Date.t(),
          allowance_required: non_neg_integer(),
          is_over: boolean()
        }

  embedded_schema do
    field :end_date, :date
    field :allowance_required, :integer
    field :is_over, :boolean
  end

  @spec start_changeset(User.t(), non_neg_integer()) :: Ecto.Changeset.t()
  @doc """
  Starts a account locking grace period of 7 days by changing the User struct.
  """
  def start_changeset(%User{} = user, allowance_required) do
    grace_period = %__MODULE__{
      end_date: Timex.shift(Timex.today(), days: 7),
      allowance_required: allowance_required,
      is_over: false
    }

    Ecto.Changeset.change(user, grace_period: grace_period)
  end

  @spec end_changeset(User.t()) :: Ecto.Changeset.t()
  @doc """
  Ends an existing grace period by `setting users.grace_period.is_over` to true.
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

  @spec active?(User.t()) :: boolean()
  @doc """
  Returns whether the grace period is still active for a User. Defaults to
  false if the user is nil or there is no grace period.
  """
  def active?(user)

  def active?(%User{grace_period: %__MODULE__{end_date: %Date{} = end_date}}) do
    Timex.diff(end_date, Timex.today(), :days) >= 0
  end

  def active?(_user), do: false

  @spec expired?(User.t()) :: boolean()
  @doc """
  Returns whether the grace period has already expired for a User. Defaults to
  false if the user is nil or there is no grace period.
  """
  def expired?(user) do
    if user && user.grace_period, do: !active?(user), else: false
  end
end
