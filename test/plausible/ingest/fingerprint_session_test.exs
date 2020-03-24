defmodule Plausible.Ingest.FingerprintSessionTest do
  use Plausible.DataCase
  alias Plausible.Ingest

  defp capture_session(fingerprint) do
    session_pid = :global.whereis_name(fingerprint)
    Process.monitor(session_pid)

    assert_receive({:DOWN, session_pid, :process, _, :normal})

    Repo.one(Plausible.FingerprintSession)
  end

  describe "on_event/1" do
    test "starts a new session if there is no session for user id" do
      pageview = insert(:pageview)

      refute is_pid(:global.whereis_name(pageview.fingerprint))

      Ingest.FingerprintSession.on_event(pageview)

      assert is_pid(:global.whereis_name(pageview.fingerprint))
    end

    test "copies event data to session" do
      pageview = insert(:pageview)

      Ingest.FingerprintSession.on_event(pageview)

      session = capture_session(pageview.fingerprint)

      assert session.fingerprint == pageview.fingerprint
      assert session.start == pageview.timestamp
    end

    test "inserts bounced session when timeout fires after one pageview" do
      pageview = insert(:pageview)

      Ingest.FingerprintSession.on_event(pageview)

      session = capture_session(pageview.fingerprint)
      assert session.is_bounce
    end

    test "session with two events is not a bounce" do
      pageview = insert(:pageview)
      pageview2 = insert(:pageview, fingerprint: pageview.fingerprint)

      Ingest.FingerprintSession.on_event(pageview)
      Ingest.FingerprintSession.on_event(pageview2)

      session = capture_session(pageview.fingerprint)
      refute session.is_bounce
    end

    test "captures the exit page" do
      pageview = insert(:pageview)
      pageview2 = insert(:pageview, fingerprint: pageview.fingerprint, pathname: "/exit")

      Ingest.FingerprintSession.on_event(pageview)
      Ingest.FingerprintSession.on_event(pageview2)

      session = capture_session(pageview.fingerprint)
      assert session.exit_page == "/exit"
    end
  end

  describe "on_unload/1" do
    test "uses the unload timestamp to calculate session length" do
      pageview = insert(:pageview)
      unload_timestamp = Timex.shift(pageview.timestamp, seconds: 30)

      Ingest.FingerprintSession.on_event(pageview)
      Ingest.FingerprintSession.on_unload(pageview.fingerprint, unload_timestamp)

      session = capture_session(pageview.fingerprint)
      assert session.length == 30
    end
  end
end
