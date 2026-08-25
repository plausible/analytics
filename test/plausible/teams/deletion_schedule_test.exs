defmodule Plausible.Teams.DeletionScheduleTest do
  use ExUnit.Case, async: true

  alias Plausible.Teams.DeletionSchedule

  describe "deletion_offset_days/1" do
    test "returns the trial offset for :expired_trial" do
      assert DeletionSchedule.deletion_offset_days(:expired_trial) == 60
    end

    test "returns the subscription offset for :churned_subscription" do
      assert DeletionSchedule.deletion_offset_days(:churned_subscription) == 180
    end
  end

  describe "deletion_date/2" do
    test "adds the trial offset to the expiry date" do
      assert DeletionSchedule.deletion_date(:expired_trial, ~D[2026-01-01]) == ~D[2026-03-02]
    end

    test "adds the subscription offset to the expiry date" do
      assert DeletionSchedule.deletion_date(:churned_subscription, ~D[2026-01-01]) ==
               ~D[2026-06-30]
    end
  end

  describe "first_notice_due_date/1" do
    test "is 30 days before the deletion date" do
      assert DeletionSchedule.first_notice_due_date(~D[2026-03-02]) == ~D[2026-01-31]
    end
  end

  describe "reminder_due_date/1" do
    test "is 5 days before the deletion date" do
      assert DeletionSchedule.reminder_due_date(~D[2026-03-02]) == ~D[2026-02-25]
    end
  end

  describe "backlog_deletion_date/1" do
    test "is anchored to when the first notice was actually sent, not a planned date" do
      assert DeletionSchedule.backlog_deletion_date(~N[2026-08-20 10:00:00]) == ~D[2026-09-19]
    end

    test "slides forward if the notice went out later than originally planned" do
      on_time = DeletionSchedule.backlog_deletion_date(~N[2026-08-20 10:00:00])
      delayed = DeletionSchedule.backlog_deletion_date(~N[2026-08-25 10:00:00])

      assert Date.diff(delayed, on_time) == 5
    end
  end

  describe "backlog_reminder_due_date/1" do
    test "is 25 days after the first notice was sent (5 days before the 30-day backlog deletion)" do
      first_notice_sent_at = ~N[2026-08-20 10:00:00]

      assert DeletionSchedule.backlog_reminder_due_date(first_notice_sent_at) == ~D[2026-09-14]

      assert Date.diff(
               DeletionSchedule.backlog_deletion_date(first_notice_sent_at),
               DeletionSchedule.backlog_reminder_due_date(first_notice_sent_at)
             ) == 5
    end
  end
end
