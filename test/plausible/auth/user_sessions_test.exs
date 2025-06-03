defmodule Plausible.Auth.UserSessionsTest do
  use Plausible.DataCase, async: true

  alias Plausible.Auth
  alias Plausible.Auth.UserSessions
  alias Plausible.Repo

  describe "list_for_user/2" do
    test "lists user sessions" do
      user = insert(:user)

      now = NaiveDateTime.utc_now(:second)
      thirty_minutes_ago = NaiveDateTime.shift(now, minute: -30)
      ten_hours_ago = NaiveDateTime.shift(now, hour: -10)
      ten_days_ago = NaiveDateTime.shift(now, day: -10)
      twenty_days_ago = NaiveDateTime.shift(now, day: -20)

      recent_session = insert_session(user, "Recent Device", thirty_minutes_ago)
      old_session = insert_session(user, "Old Device", ten_hours_ago)
      older_session = insert_session(user, "Older Device", ten_days_ago)
      _expired_session = insert_session(user, "Expired Device", twenty_days_ago)
      _rogue_session = insert_session(insert(:user), "Unrelated device", now)

      assert [session1, session2, session3] = UserSessions.list_for_user(user, now)

      assert session1.id == recent_session.id
      assert session2.id == old_session.id
      assert session3.id == older_session.id
    end
  end

  describe "last_used_humanize/2" do
    test "returns humanized relative time" do
      user = insert(:user)
      now = NaiveDateTime.utc_now(:second)
      thirty_minutes_ago = NaiveDateTime.shift(now, minute: -30)
      ninety_minutes_ago = NaiveDateTime.shift(now, minute: -90)
      ten_hours_ago = NaiveDateTime.shift(now, hour: -10)
      twenty_seven_hours_ago = NaiveDateTime.shift(now, hour: -27)
      fifty_hours_ago = NaiveDateTime.shift(now, hour: -50)
      ten_days_ago = NaiveDateTime.shift(now, day: -10)

      assert last_used_humanize(user, now) == "Just recently"
      assert last_used_humanize(user, thirty_minutes_ago) == "Just recently"
      assert last_used_humanize(user, ninety_minutes_ago) == "1 hour ago"
      assert last_used_humanize(user, ten_hours_ago) == "10 hours ago"
      assert last_used_humanize(user, twenty_seven_hours_ago) == "Yesterday"
      assert last_used_humanize(user, fifty_hours_ago) == "2 days ago"
      assert last_used_humanize(user, ten_days_ago) == "10 days ago"
    end
  end

  defp last_used_humanize(user, dt) do
    user
    |> insert_session("Some Device", dt)
    |> UserSessions.last_used_humanize()
  end

  defp insert_session(user, device_name, now) do
    user
    |> Auth.UserSession.new_session(device_name, now)
    |> Repo.insert!()
  end
end
