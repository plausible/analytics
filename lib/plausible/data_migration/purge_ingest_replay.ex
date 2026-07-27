defmodule Plausible.DataMigration.PurgeIngestReplay do
  @moduledoc """
  Script purging ingest replay
  """

  alias Plausible.IngestRepo

  @settings if Mix.env() in [:test, :ce_test, :e2e_test], do: [mutations_sync: 2], else: []

  @confirmation_phrase "REMOVE REPLAYED INGEST"

  @count_query """
  SELECT count(*) AS count FROM {$0:Identifier} 
  WHERE replay_session_id = {$1:UInt64} 
    AND toDate(timestamp) >= {$2:Date} 
    AND toDate(timestamp) <= {$3:Date}
  """

  @purge_query """
  ALTER TABLE {$0:Identifier} DELETE 
  WHERE replay_session_id = {$1:UInt64} 
    AND toDate(timestamp) >= {$2:Date} 
    AND toDate(timestamp) <= {$3:Date}
  """

  def run(opts \\ []) do
    from = %Date{} = Keyword.fetch!(opts, :from)
    to = %Date{} = Keyword.fetch!(opts, :to)
    session_id = String.to_integer(Keyword.fetch!(opts, :session_id))

    days_scope = Date.diff(to, from)

    if session_id <= 0 do
      raise ArgumentError, "Invalid session ID"
    end

    if days_scope < 0 or days_scope > 2 do
      raise ArgumentError, "The number of days between the dates must be from 0 to 2 range"
    end

    %{rows: [[session_count]]} =
      IngestRepo.query!(@count_query, ["sessions_v2", session_id, from, to], @settings)

    %{rows: [[event_count]]} =
      IngestRepo.query!(@count_query, ["events_v2", session_id, from, to], @settings)

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
    IngestRepo.query!(@purge_query, ["sessions_v2", session_id, from, to], @settings)

    IO.puts("Purging events...")
    IngestRepo.query!(@purge_query, ["events_v2", session_id, from, to], @settings)

    IO.puts("Done!")
  end
end
