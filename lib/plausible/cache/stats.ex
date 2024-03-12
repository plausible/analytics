defmodule Plausible.Cache.Stats do
  @moduledoc """
  Keeps track of hit/miss ratio for various caches.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    table = Keyword.get(opts, :table, __MODULE__)

    ^table =
      :ets.new(table, [
        :public,
        :named_table,
        :ordered_set,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, table}
  end

  def gather(cache_name, table \\ __MODULE__) do
    {:ok,
     %{
       hit_rate: hit_rate(cache_name, table),
       count: size(cache_name) || 0
     }}
  end

  defdelegate size(cache_name), to: Plausible.Cache.Adapter

  def track(item, cache_name, table \\ __MODULE__)

  def track({:from_fallback, item}, cache_name, table) do
    bump(cache_name, :miss, 1, table)
    item
  end

  def track(nil, cache_name, table) do
    bump(cache_name, :miss, 1, table)
    nil
  end

  def track(item, cache_name, table) do
    bump(cache_name, :hit, 1, table)
    item
  end

  def bump(cache_name, type, increment, table \\ __MODULE__) do
    :ets.update_counter(
      table,
      {cache_name, type},
      increment,
      {{cache_name, type}, 0}
    )
  end

  def hit_rate(cache_name, table \\ __MODULE__) do
    hit = :ets.lookup_element(table, {cache_name, :hit}, 2, 0)
    miss = :ets.lookup_element(table, {cache_name, :miss}, 2, 0)
    hit_miss = hit + miss

    if hit_miss == 0 do
      0.0
    else
      hit / hit_miss * 100
    end
  end
end
