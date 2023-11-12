defmodule Plausible.Event.WriteBuffer do
  def child_spec(opts) do
    opts = Keyword.merge([name: __MODULE__, schema: Plausible.ClickhouseEventV2], opts)
    Plausible.Ingestion.WriteBuffer.child_spec(opts)
  end

  def start_link(opts) do
    opts = Keyword.merge([name: __MODULE__, schema: Plausible.ClickhouseEventV2], opts)
    Plausible.Ingestion.WriteBuffer.start_link(opts)
  end

  @spec insert(GenServer.name(), event) :: event when event: %Plausible.ClickhouseEventV2{}
  def insert(server \\ __MODULE__, event) do
    Plausible.Ingestion.WriteBuffer.insert(server, Plausible.ClickhouseEventV2, event)
  end

  def flush(server \\ __MODULE__) do
    Plausible.Ingestion.WriteBuffer.flush(server)
  end
end
