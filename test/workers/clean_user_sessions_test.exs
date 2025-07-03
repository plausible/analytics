defmodule Plausible.Workers.CleanUserSessionsTest do
  use Plausible.DataCase
  use Plausible.Teams.Test

  alias Plausible.Auth.UserSession
  alias Plausible.Workers.CleanUserSessions

  test "cleans invitation that is more than timeout_at + grace_period days old" do
    grace_cutoff =
      NaiveDateTime.utc_now(:second)
      |> NaiveDateTime.shift(Duration.negate(UserSession.timeout_duration()))
      |> NaiveDateTime.shift(CleanUserSessions.grace_period_duration())

    ten_days_after = NaiveDateTime.shift(grace_cutoff, day: 10)
    one_day_after = NaiveDateTime.shift(grace_cutoff, day: 1)
    one_day_before = NaiveDateTime.shift(grace_cutoff, day: -1)
    session_to_clean = insert_session(one_day_before)
    session_to_leave1 = insert_session(one_day_after)
    session_to_leave2 = insert_session(ten_days_after)

    CleanUserSessions.perform(nil)

    refute Repo.reload(session_to_clean)
    assert Repo.reload(session_to_leave1)
    assert Repo.reload(session_to_leave2)
  end

  defp insert_session(now) do
    user = new_user()

    user
    |> UserSession.new_session("Unknown", now: now)
    |> Repo.insert!()
  end
end
