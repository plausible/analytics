defmodule Plausible.Cache.Stats do
  @moduledoc """
  Keeps track of hit/miss ratio for various caches.
  """

  use GenServer

  @hit :hit
  @miss :miss
  @telemetry_hit ConCache.Operations.telemetry_hit()
  @telemetry_miss ConCache.Operations.telemetry_miss()
  @telemetry_events [@telemetry_hit, @telemetry_miss]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(nil) do
    __MODULE__ =
      :ets.new(__MODULE__, [
        :public,
        :named_table,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    :telemetry.attach_many(
      "plausible-cache-stats",
      @telemetry_events,
      &__MODULE__.handle_telemetry_event/4,
      nil
    )

    {:ok, nil}
  end

  def handle_telemetry_event(@telemetry_hit, _measurements, %{cache: %{name: cache_name}}, _) do
    bump(cache_name, @hit)
  end

  def handle_telemetry_event(@telemetry_miss, _measurements, %{cache: %{name: cache_name}}, _) do
    bump(cache_name, @miss)
  end

  def gather(cache_name) do
    {:ok,
     %{
       hit_rate: hit_rate(cache_name),
       count: size(cache_name) || 0
     }}
  end

  defdelegate size(cache_name), to: Plausible.Cache.Adapter

  def bump(cache_name, type) do
    :ets.update_counter(
      __MODULE__,
      {cache_name, type},
      1,
      {{cache_name, type}, 0}
    )
  end

  def hit_rate(cache_name) do
    hit = :ets.lookup_element(__MODULE__, {cache_name, @hit}, 2, 0)
    miss = :ets.lookup_element(__MODULE__, {cache_name, @miss}, 2, 0)
    hit_miss = hit + miss

    if hit_miss == 0 do
      0.0
    else
      hit / hit_miss * 100
    end
  end
end
