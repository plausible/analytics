defmodule Plausible.TeamDeletionSchedule do
  @moduledoc """
  Schema for tracking the notify-delete lifecycle of teams whose trial
  or subscription has expired, ahead of their stats being removed.
  """

  use Ecto.Schema

  @categories [:expired_trial, :expired_subscription]
  @statuses [:scheduled, :first_notice_sent, :reminder_sent, :deleted, :cancelled, :snoozed]

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
end
