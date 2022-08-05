defmodule Plausible.Ingestion.Drain do
  @moduledoc """
  The drain is a GenStage consumer that takes requests, transforms them into
  %Plausible.ClickhouseEvent{} structs, and calls Plausible.Event.WriteBuffer, eventually
  inserting data into Clickhouse.
  """

  require Logger
  use GenStage

  def start_link(_opts) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:consumer, :state_does_not_matter,
     subscribe_to: [{Plausible.Ingestion.Sink, max_demand: 100}]}
  end

  def handle_events(requests, _from, state) do
    Logger.info("Ingestion: Draining #{length(requests)} event requests")

    Enum.each(requests, fn request ->
      # FIXME: Remove this before merging. This is just to test when ingestion takes a while.
      Process.sleep(500 + :rand.uniform(1000))

      Plausible.Ingestion.add_to_buffer(request)
    end)

    Logger.info("Ingestion: Finished draining")

    {:noreply, [], state}
  end
end
