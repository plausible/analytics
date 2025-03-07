defmodule Plausible.Cache.Stats do
  @moduledoc """
  Keeps track of hit/miss ratio for various caches.
  """

  @hit :hit
  @miss :miss
  @telemetry_hit ConCache.Operations.telemetry_hit()
  @telemetry_miss ConCache.Operations.telemetry_miss()
  @telemetry_events [@telemetry_hit, @telemetry_miss]

  def attach do
    :telemetry.attach_many(
      "plausible-cache-stats",
      @telemetry_events,
      &__MODULE__.handle_telemetry_event/4,
      nil
    )

    {:ok, nil}
  end

  def create_counters(cache_name) do
    :persistent_term.put({__MODULE__, cache_name, @hit}, :counters.new(1, []))
    :persistent_term.put({__MODULE__, cache_name, @miss}, :counters.new(1, []))
  end

  defp counter(cache_name, type) do
    :persistent_term.get({__MODULE__, cache_name, type}, nil) ||
      raise "counter not found for #{cache_name} #{type}"
  end

  def handle_telemetry_event(@telemetry_hit, _measurments, %{cache: %{name: cache_name}}, _) do
    bump(cache_name, @hit)
  end

  def handle_telemetry_event(@telemetry_miss, _measurments, %{cache: %{name: cache_name}}, _) do
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
    :counters.add(counter(cache_name, type), 1, 1)
  end

  def hit_rate(cache_name) do
    cache_name
    |> Plausible.Cache.Adapter.get_names()
    |> Enum.reduce(
      %{hit: 0, miss: 0, hit_miss: 0.0},
      fn name, acc ->
        hit = acc.hit + :counters.get(counter(name, @hit), 1)
        miss = acc.miss + :counters.get(counter(name, @miss), 1)
        hit_miss = hit + miss
        hit_miss = if(hit_miss == 0, do: 0.0, else: hit / hit_miss * 100)

        acc
        |> Map.put(:hit, hit)
        |> Map.put(:miss, miss)
        |> Map.put(:hit_miss, hit_miss)
      end
    )
    |> Map.fetch!(:hit_miss)
  end
end
