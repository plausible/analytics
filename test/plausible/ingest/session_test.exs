defmodule Plausible.Ingest.SessionTest do
  use Plausible.DataCase
  alias Plausible.Ingest

  defp capture_session(user_id) do
    session_pid = :global.whereis_name(user_id)
    Process.monitor(session_pid)

    assert_receive({:DOWN, session_pid, :process, _, :normal})

    Repo.one(Plausible.Session)
  end

  describe "on_event/1" do
    test "starts a new session if there is no session for user id" do
      pageview = insert(:pageview)

      refute is_pid(:global.whereis_name(pageview.user_id))

      Ingest.Session.on_event(pageview)

      assert is_pid(:global.whereis_name(pageview.user_id))
    end

    test "copies event data to session" do
      pageview = insert(:pageview)

      Ingest.Session.on_event(pageview)

      session = capture_session(pageview.user_id)

      assert session.user_id == pageview.user_id
      assert session.new_visitor == pageview.new_visitor
      assert session.start == pageview.timestamp
    end

    test "inserts bounced session when timeout fires after one pageview" do
      pageview = insert(:pageview)

      Ingest.Session.on_event(pageview)

      session = capture_session(pageview.user_id)
      assert session.is_bounce
    end

    test "session with two events is not a bounce" do
      pageview = insert(:pageview)
      pageview2 = insert(:pageview, user_id: pageview.user_id)

      Ingest.Session.on_event(pageview)
      Ingest.Session.on_event(pageview2)

      session = capture_session(pageview.user_id)
      refute session.is_bounce
    end
  end

  describe "on_unload/1" do
    test "uses the unload timestamp to calculate session length" do
      pageview = insert(:pageview)
      unload_timestamp = Timex.shift(pageview.timestamp, seconds: 30)

      Ingest.Session.on_event(pageview)
      Ingest.Session.on_unload(pageview.user_id, unload_timestamp)

      session = capture_session(pageview.user_id)
      assert session.length == 30
    end
  end
end
