defmodule Plausible.Ingestion.Persistor.Embedded do
  @moduledoc """
  Embedded implementation of session and event persistence.
  """

  alias Plausible.ClickhouseEventV2

  require Logger

  def persist_event(event, session_attrs, previous_user_id, opts \\ []) do
    session_write_buffer_insert =
      Keyword.get(opts, :session_write_buffer_insert, &Plausible.Session.WriteBuffer.insert/1)

    event_write_buffer_insert =
      Keyword.get(opts, :event_write_buffer_insert, &Plausible.Event.WriteBuffer.insert/1)

    session_result =
      Plausible.Session.CacheStore.on_event(
        event,
        session_attrs,
        previous_user_id,
        buffer_insert: session_write_buffer_insert
      )

    case session_result do
      {:ok, :no_session_for_engagement} ->
        {:error, :no_session_for_engagement}

      {:error, :timeout} ->
        {:error, :lock_timeout}

      {:ok, session} ->
        event = ClickhouseEventV2.merge_session(event, session)
        {:ok, _} = event_write_buffer_insert.(event)

        {:ok, event}
    end
  end
end
