defmodule Plausible.Ingestion.Sink do
  @moduledoc """
  The ingestion sink queue is where all events go. This is a GenStage push-based producer consumed
  by Plausible.Ingestion.Drain. It buffers incoming requests until a consumer registers demand.
  """

  require Logger
  use GenStage

  def enqueue(request) do
    GenServer.cast(__MODULE__, {:enqueue, request})
  end

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # TODO: if set, max_buffer_size will start shedding load after a certain limit
  @max_buffer_size :infinity
  def init(:ok) do
    {:producer, {:queue.new(), 0}, buffer_size: @max_buffer_size}
  end

  def handle_demand(incoming_demand, {queue, pending_demand}) do
    {requests, {queue, _pending_demand} = state} =
      dequeue(queue, incoming_demand + pending_demand, [])

    Logger.info("Ingestion: Consumer registered demand for #{incoming_demand}")

    Logger.info(
      "Ingestion: Dispatching #{length(requests)} request. Current queue: #{:queue.len(queue)}"
    )

    {:noreply, requests, state}
  end

  def handle_cast({:enqueue, request}, {queue, 0}) do
    queue = :queue.in(request, queue)
    Logger.info("Ingestion: Buffering request. Current queue: #{:queue.len(queue)}")
    {:noreply, [], {queue, 0}}
  end

  def handle_cast({:enqueue, request}, {queue, pending_demand}) do
    {requests, {queue, _pending_demand} = state} =
      request
      |> :queue.in(queue)
      |> dequeue(pending_demand, [])

    Logger.info(
      "Ingestion: Dispatching #{length(requests)} requests. Current queue: #{:queue.len(queue)}"
    )

    {:noreply, requests, state}
  end

  defp dequeue(queue, 0, requests) do
    {requests, {queue, 0}}
  end

  defp dequeue(queue, demand, requests) do
    case :queue.out(queue) do
      {{:value, request}, queue} ->
        dequeue(queue, demand - 1, [request | requests])

      {:empty, queue} ->
        {requests, {queue, demand}}
    end
  end
end
