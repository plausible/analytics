defmodule Plausible.Ingestion do
  alias Plausible.Ingestion.{Event, Session, Request}

  @spec from_requests([Request.t()]) :: :ok
  @doc """
  Ingests a list of requests. If a session already exists for the request, it uses the existing
  one, otherwise it creates a new session. Events and sessions are buffered before being inserted
  into Clickhouse.
  """
  def from_requests(requests) do
    Enum.each(requests, fn request ->
      user_id = Event.get_user_id(request)
      pid = Session.DynamicSupervisor.find_or_spawn(request.domain, user_id)

      Session.Actor.send_event(pid, request)
    end)
  end
end
