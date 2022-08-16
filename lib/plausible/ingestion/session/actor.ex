defmodule Plausible.Ingestion.Session.Actor do
  @moduledoc """
  The Session actor is a short-lived process spawned for each incoming session. The process self
  destructs after 30 minutes from the first event.
  """

  alias Plausible.{Ingestion, Ingestion.Session}
  require Logger
  use GenServer, restart: :transient, shutdown: :timer.minutes(30)

  @spec send_event(pid(), map()) :: :ok
  def send_event(pid, request_or_event), do: GenServer.cast(pid, {:send_event, request_or_event})

  defmodule State do
    defstruct [:domain, :user_id, :session]

    @type t() :: %__MODULE__{
            domain: String.t(),
            user_id: integer(),
            session: %Plausible.ClickhouseSession{} | nil
          }
  end

  def start_link({domain, user_id}) do
    process_name = {:via, Registry, {Ingestion.Session.Registry, {domain, user_id}}}
    GenServer.start_link(__MODULE__, {domain, user_id}, name: process_name)
  end

  @impl true
  def init({domain, user_id}) do
    Logger.debug("Ingestion: Starting new session for #{domain}@#{user_id}")

    {:ok, %State{domain: domain, user_id: user_id}}
  end

  @impl true
  def handle_cast({:send_event, request_or_event}, %State{} = state) do
    Logger.debug("Ingestion: Processing new event for session #{state.domain}@#{state.user_id}")

    with {:ok, event} <- build_event(request_or_event),
         session <- Session.upsert_from_event(state.session, event),
         event <- %Plausible.ClickhouseEvent{event | session_id: session.session_id},
         {:ok, _event} <- Plausible.Event.WriteBuffer.insert(event) do
      {:noreply, %State{state | session: session}}
    else
      :skip ->
        Logger.debug("Ingestion: Skipping spam/bot event")
        {:noreply, state}

      {:error, changeset} ->
        Logger.error("Ingestion: Failed to insert event. Reason: #{inspect(changeset)}")
        {:noreply, state}
    end
  end

  defp build_event(%Ingestion.Request{} = request), do: Ingestion.Event.build(request)
  defp build_event(%Plausible.ClickhouseEvent{} = event), do: {:ok, event}
end
