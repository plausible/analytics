defmodule Plausible.DataMigration.PurgeIngestReplayTest do
  use Plausible

  on_ee do
    use Plausible.DataCase, async: true

    import ExUnit.CaptureIO

    alias Plausible.DataMigration.PurgeIngestReplay

    describe "run/1" do
      test "aborts where there are no replayed events within range" do
        assert capture_io(fn ->
                 assert {:error, :aborted} =
                          PurgeIngestReplay.run(
                            from: ~D[2026-07-26],
                            to: ~D[2026-07-27],
                            session_id: 123
                          )
               end) =~ "No events found matching criteria. Aborting"
      end

      test "purges replayed events in scope" do
        site = new_site()

        replay_session_id = random_id()
        other_replay_session_id = random_id()

        populate_stats(site, [
          # out of scope
          build(:pageview,
            timestamp: ~N[2026-07-25 11:44:56],
            replay_session_id: replay_session_id
          ),
          # different replay
          build(:pageview,
            timestamp: ~N[2026-07-25 11:44:56],
            replay_session_id: other_replay_session_id
          ),
          # non-replay event
          build(:pageview, timestamp: ~N[2026-07-25 11:44:56]),
          # in scope
          build(:pageview,
            timestamp: ~N[2026-07-26 11:44:56],
            replay_session_id: replay_session_id
          ),
          build(:pageview,
            user_id: 456,
            timestamp: ~N[2026-07-26 13:12:33],
            replay_session_id: replay_session_id
          ),
          build(:pageview,
            user_id: 456,
            timestamp: ~N[2026-07-26 13:32:43],
            replay_session_id: replay_session_id
          ),
          build(:pageview,
            timestamp: ~N[2026-07-27 14:44:56],
            replay_session_id: replay_session_id
          )
        ])

        output =
          capture_io("REMOVE REPLAYED INGEST", fn ->
            assert :ok =
                     PurgeIngestReplay.run(
                       from: ~D[2026-07-26],
                       to: ~D[2026-07-27],
                       session_id: replay_session_id
                     )
          end)

        assert output =~ "About to remove replayed ingest for session ID #{replay_session_id}"
        assert output =~ "Start date: 2026-07-26"
        assert output =~ "End date: 2026-07-27"
        assert output =~ "Sessions found: 3"
        assert output =~ "Events found: 4"
        assert output =~ "Purging sessions..."
        assert output =~ "Purging events..."
        assert output =~ "Done!"

        assert eventually(fn ->
                 assert %{rows: [[session_count]]} =
                          Plausible.IngestRepo.query!(
                            "SELECT count(*) FROM events_v2 WHERE replay_session_id = #{replay_session_id}"
                          )

                 assert %{rows: [[event_count]]} =
                          Plausible.IngestRepo.query!(
                            "SELECT count(*) FROM sessions_v2 WHERE replay_session_id = #{replay_session_id}"
                          )

                 # only out of scope event is left
                 {session_count == 1 and event_count == 1, true}
               end)
      end

      test "aborts when no matching replay events are in scope" do
        site = new_site()

        replay_session_id = random_id()
        other_replay_session_id = random_id()

        populate_stats(site, [
          # out of scope
          build(:pageview,
            timestamp: ~N[2026-07-25 11:44:56],
            replay_session_id: replay_session_id
          ),
          # different replay
          build(:pageview,
            timestamp: ~N[2026-07-25 11:44:56],
            replay_session_id: other_replay_session_id
          ),
          # non-replay event
          build(:pageview, timestamp: ~N[2026-07-25 11:44:56])
        ])

        assert capture_io(fn ->
                 assert {:error, :aborted} =
                          PurgeIngestReplay.run(
                            from: ~D[2026-07-26],
                            to: ~D[2026-07-27],
                            session_id: replay_session_id
                          )
               end) =~ "No events found matching criteria. Aborting"
      end

      test "raises on invalid session ID" do
        assert_raise ArgumentError, ~r/Invalid session ID/, fn ->
          PurgeIngestReplay.run(
            from: ~D[2026-07-26],
            to: ~D[2026-07-27],
            session_id: 0
          )

          assert_raise MatchError, fn ->
            PurgeIngestReplay.run(
              from: ~D[2026-07-26],
              to: ~D[2026-07-27],
              session_id: :invalid
            )
          end
        end
      end

      test "raises on invalid session date range" do
        assert_raise ArgumentError,
                     ~r/The number of days between the dates must be from 0 to 2 range/,
                     fn ->
                       PurgeIngestReplay.run(
                         from: ~D[2026-07-27],
                         to: ~D[2026-07-26],
                         session_id: 123
                       )
                     end

        assert_raise ArgumentError,
                     ~r/The number of days between the dates must be from 0 to 2 range/,
                     fn ->
                       PurgeIngestReplay.run(
                         from: ~D[2026-07-26],
                         to: ~D[2026-07-29],
                         session_id: 123
                       )
                     end

        assert_raise MatchError, fn ->
          PurgeIngestReplay.run(
            from: ~D[2026-07-26],
            to: :invalid,
            session_id: 123
          )
        end

        assert_raise MatchError, fn ->
          PurgeIngestReplay.run(
            from: :invalid,
            to: ~D[2026-07-29],
            session_id: 123
          )
        end
      end
    end

    defp random_id() do
      :crypto.strong_rand_bytes(8)
      |> :binary.decode_unsigned()
    end
  end
end
