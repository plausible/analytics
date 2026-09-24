defmodule Plausible.DataMigration.PurgeIngestReplay do
  @moduledoc """
  Script purging ingest replay.

  The script is used in the ingest replay procedure when a particular replay turns
  out to be incorrect - for instance, due to too much overlap with normally ingestged
  events.

  Three options are required:

  - `session_id` - `replay_session_id` to purge, provided as an integer
  - `from` and `to` - provided as Dates; necessary for reducing scope of database scan; 
    the date range is inclusive; to scan a single day, `from` and `to` can be the same;
    maximum range is 3 days
  """

  alias Plausible.IngestRepo

  @settings if Mix.env() in [:test, :ce_test, :e2e_test], do: [mutations_sync: 2], else: []

  @confirmation_phrase "REMOVE REPLAYED INGEST"

  @count_query_sessions """
  SELECT count(*) AS count FROM sessions_v2 
  WHERE replay_session_id = {$0:UInt64} 
    AND toDate(start) >= {$1:Date} 
    AND toDate(start) <= {$2:Date}
  """

  @count_query_events """
  SELECT count(*) AS count FROM events_v2 
  WHERE replay_session_id = {$0:UInt64} 
    AND toDate(timestamp) >= {$1:Date} 
    AND toDate(timestamp) <= {$2:Date}
  """

  @purge_query_sessions """
  ALTER TABLE sessions_v2 DELETE 
  WHERE replay_session_id = {$0:UInt64} 
    AND toDate(start) >= {$1:Date} 
    AND toDate(start) <= {$2:Date}
  """

  @purge_query_events """
  ALTER TABLE events_v2 DELETE 
  WHERE replay_session_id = {$0:UInt64} 
    AND toDate(timestamp) >= {$1:Date} 
    AND toDate(timestamp) <= {$2:Date}
  """

  def run(opts \\ []) do
    from = %Date{} = Keyword.fetch!(opts, :from)
    to = %Date{} = Keyword.fetch!(opts, :to)
    session_id = Keyword.fetch!(opts, :session_id)

    days_scope = Date.diff(to, from)

    if not is_integer(session_id) or session_id <= 0 do
      raise ArgumentError, "Invalid session ID"
    end

    if days_scope < 0 or days_scope > 2 do
      raise ArgumentError,
            "The period declared by inclusive from/to range cannot be longer than 3 days"
    end

    %{rows: [[session_count]]} =
      IngestRepo.query!(
        @count_query_sessions,
        [session_id, from, to],
        @settings
      )

    %{rows: [[event_count]]} =
      IngestRepo.query!(@count_query_events, [session_id, from, to], @settings)

    if session_count > 0 or event_count > 0 do
      IO.puts("""
      About to remove replayed ingest for session ID #{session_id}

      Start date: #{from}
      End date: #{to}

      Sessions found: #{session_count}
      Events found: #{event_count}

      To confirm, please type in:

      #{@confirmation_phrase}

      and hit Enter.

      """)

      confirmation = IO.gets("Confirmation: ")

      if String.trim(confirmation) == @confirmation_phrase do
        run_purge(session_id, from, to)
      else
        IO.puts("Wrong confirmation phrase. Aborting!")
        {:error, :aborted}
      end
    else
      IO.puts("No events found matching criteria. Aborting.")
      {:error, :aborted}
    end
  end

  defp run_purge(session_id, from, to) do
    IO.puts("Purging sessions...")

    IngestRepo.query!(
      @purge_query_sessions,
      [session_id, from, to],
      @settings
    )

    IO.puts("Purging events...")
    IngestRepo.query!(@purge_query_events, [session_id, from, to], @settings)

    IO.puts("Done!")
  end
end
