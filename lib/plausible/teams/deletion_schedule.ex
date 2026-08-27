defmodule Plausible.Teams.DeletionSchedule do
  @moduledoc """
  Inactive team deletion schedule
  """

  @trial_deletion_offset_days 60
  @subscription_deletion_offset_days 180

  @first_notice_before_deletion_days 30
  @reminder_before_deletion_days 5

  @backlog_deletion_offset_days 30
  @backlog_release_window_days 30

  # how many domains to include in notifications
  @notification_site_list_limit 3

  def trial_deletion_offset_days, do: @trial_deletion_offset_days
  def subscription_deletion_offset_days, do: @subscription_deletion_offset_days
  def first_notice_before_deletion_days, do: @first_notice_before_deletion_days
  def reminder_before_deletion_days, do: @reminder_before_deletion_days
  def backlog_deletion_offset_days, do: @backlog_deletion_offset_days
  def backlog_release_window_days, do: @backlog_release_window_days
  def notification_site_list_limit, do: @notification_site_list_limit

  @spec deletion_offset_days(:expired_trial | :churned_subscription) :: pos_integer()
  def deletion_offset_days(:expired_trial), do: @trial_deletion_offset_days
  def deletion_offset_days(:churned_subscription), do: @subscription_deletion_offset_days

  @spec deletion_date(:expired_trial | :churned_subscription, Date.t()) :: Date.t()
  def deletion_date(category, expiry_date) do
    Date.add(expiry_date, deletion_offset_days(category))
  end

  @spec first_notice_due_date(Date.t()) :: Date.t()
  def first_notice_due_date(deletion_date),
    do: Date.add(deletion_date, -@first_notice_before_deletion_days)

  @spec reminder_due_date(Date.t()) :: Date.t()
  def reminder_due_date(deletion_date),
    do: Date.add(deletion_date, -@reminder_before_deletion_days)

  @spec backlog_deletion_date(NaiveDateTime.t()) :: Date.t()
  def backlog_deletion_date(first_notice_sent_at) do
    first_notice_sent_at
    |> NaiveDateTime.to_date()
    |> Date.add(@backlog_deletion_offset_days)
  end
end
