defmodule Plausible.Ingestion.Persistor.EmbeddedWithRelay do
  @moduledoc """
  Embedded implementation with async relay to remote.
  """

  alias Plausible.Ingestion.Persistor

  def persist_event(event, session_attrs, previous_user_id, opts) do
    Task.start(fn ->
      Persistor.Remote.persist_event(event, session_attrs, previous_user_id, opts)
    end)

    Persistor.Embedded.persist_event(event, session_attrs, previous_user_id, opts)
  end
end
