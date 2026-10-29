defmodule Plausible.TeamDeletionSchedule do
  @moduledoc """
  Schema for tracking the notify-delete lifecycle of teams whose trial
  or subscription has expired, ahead of their stats being removed.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @categories [:expired_trial, :churned_subscription]
  @statuses [:scheduled, :first_notice_sent, :reminder_sent, :completed, :cancelled, :snoozed]

  # Indicate permanent end of schedule lifecycle
  @terminal_statuses [:cancelled, :completed]

  @type t() :: %__MODULE__{}

  schema "team_deletion_schedules" do
    belongs_to :team, Plausible.Teams.Team

    field :category, Ecto.Enum, values: @categories
    field :expiry_date, :date
    field :deletion_date, :date
    field :is_backlog, :boolean, default: false
    field :status, Ecto.Enum, values: @statuses, default: :scheduled
    field :first_notice_due_date, :date
    field :first_notice_sent_at, :naive_datetime
    field :reminder_sent_at, :naive_datetime
    field :snoozed_until, :date
    field :snooze_note, :string

    timestamps()
  end

  @spec categories() :: [atom()]
  def categories, do: @categories

  @spec statuses() :: [atom()]
  def statuses, do: @statuses

  @spec terminal_statuses() :: [atom()]
  def terminal_statuses, do: @terminal_statuses

  @spec active_statuses() :: [atom()]
  def active_statuses, do: @statuses -- @terminal_statuses

  @doc """
  Validates staff submitted snooze input from the CRM - snoozed_until is
  required and must be in the future. Doesn't touch status, the actual
  transition happens via Plausible.TeamDeletionSchedules.snooze/3.
  """
  @spec crm_changeset(t(), map()) :: Ecto.Changeset.t()
  def crm_changeset(schedule, params) do
    schedule
    |> cast(params, [:snoozed_until, :snooze_note])
    |> validate_required([:snoozed_until])
    |> validate_change(:snoozed_until, fn field, date ->
      if Date.after?(date, Date.utc_today()) do
        []
      else
        [{field, "must be in the future"}]
      end
    end)
  end
end
