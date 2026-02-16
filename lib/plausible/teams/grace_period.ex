defmodule Plausible.Teams.GracePeriod do
  @moduledoc """
  This embedded schema stores information about the account locking grace
  period.

  Teams are given this 7-day grace period to upgrade their account after
  outgrowing their subscriptions. The actual account locking happens in
  background with `Plausible.Workers.LockSites`.

  The grace period can also be manual, without an end date, being controlled
  manually from the CRM, and not by the background site locker job. This is
  useful for enterprise subscriptions.
  """

  use Ecto.Schema
  alias Plausible.Teams

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

  @spec start_changeset(Teams.Team.t()) :: Ecto.Changeset.t()
  @doc """
  Starts a account locking grace period of 7 days by changing the Team struct.
  """
  def start_changeset(%Teams.Team{} = team) do
    grace_period = %__MODULE__{
      end_date: Date.shift(Date.utc_today(), day: 7),
      is_over: false,
      manual_lock: false
    }

    Ecto.Changeset.change(team, grace_period: grace_period)
  end

  @spec start_manual_lock_changeset(Teams.Team.t()) :: Ecto.Changeset.t()
  @doc """
  Starts a manual account locking grace period by changing the Team struct.
  Manual locking means the grace period can only be removed manually from the
  CRM.
  """
  def start_manual_lock_changeset(%Teams.Team{} = team) do
    grace_period = %__MODULE__{
      end_date: nil,
      is_over: false,
      manual_lock: true
    }

    Ecto.Changeset.change(team, grace_period: grace_period)
  end

  @spec end_changeset(Teams.Team.t()) :: Ecto.Changeset.t()
  @doc """
  Ends an existing grace period by setting `teams.grace_period.is_over` to true.
  This means the grace period has expired.
  """
  def end_changeset(%Teams.Team{} = team) do
    Ecto.Changeset.change(team, grace_period: %{is_over: true})
  end

  @spec remove_changeset(Teams.Team.t()) :: Ecto.Changeset.t()
  @doc """
  Removes the grace period from the Team completely.
  """
  def remove_changeset(%Teams.Team{} = team) do
    Ecto.Changeset.change(team, grace_period: nil)
  end

  @spec active?(Teams.Team.t() | nil) :: boolean()
  @doc """
  Returns whether the grace period is still active for a Team. Defaults to
  false if the team is nil or there is no grace period.
  """
  def active?(team)

  def active?(%{grace_period: %__MODULE__{end_date: %Date{} = end_date}}) do
    Date.diff(end_date, Date.utc_today()) >= 0
  end

  def active?(%{grace_period: %__MODULE__{manual_lock: true}}) do
    true
  end

  def active?(_team), do: false

  @spec expired?(Teams.Team.t() | nil) :: boolean()
  @doc """
  Returns whether the grace period has already expired for a Team. Defaults to
  false if the team is nil or there is no grace period.
  """
  def expired?(team) do
    if team && team.grace_period, do: !active?(team), else: false
  end

  @spec expires_in(Teams.Team.t() | nil) :: {non_neg_integer(), :days | :hours} | nil
  @doc """
  Returns a tuple representing either the days (if hours_left < 48) or days left
  until the end of a grace period. Switching to hours near the end is to avoid
  confusion with timezones.

  Returns `nil` in all the following cases:

  * the given team is `nil`
  * the given team does not have a grace period
  * the given team has a manual lock grace period
  """
  def expires_in(team, now \\ NaiveDateTime.utc_now(:second))

  def expires_in(%Teams.Team{grace_period: %__MODULE__{end_date: %Date{} = end_date}}, now) do
    case full_hours_left(end_date, now) do
      hours when hours < 48 -> {hours, :hours}
      _ -> {days_left(end_date, now), :days}
    end
  end

  def expires_in(_, _), do: nil

  defp days_left(%Date{} = end_date, now) do
    today = NaiveDateTime.to_date(now)
    Date.diff(end_date, today)
  end

  defp full_hours_left(%Date{} = end_date, now) do
    end_date
    |> NaiveDateTime.new!(~T[00:00:00])
    |> NaiveDateTime.diff(now, :second)
    |> max(0)
    |> div(3600)
  end
end
