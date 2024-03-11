defmodule Plausible.Cache.Adapter do
  @moduledoc """
  Interface for the underlying cache implementation.
  Currently: ConCache

  Using the Adapter module directly, the user must ensure that the relevant
  processes are available to use, which is normally done via the child specification.
  """

  require Logger

  @spec child_spec(atom(), atom(), Keyword.t()) :: Supervisor.child_spec()
  def child_spec(name, child_id, opts \\ [])
      when is_atom(name) and is_atom(child_id) and is_list(opts) do
    cache_name = Keyword.get(opts, :cache_name, name)
    child_id = Keyword.get(opts, :child_id, child_id)
    ttl_check_interval = Keyword.get(opts, :ttl_check_interval, false)

    opts =
      opts
      |> Keyword.put(:name, cache_name)
      |> Keyword.put(:ttl_check_interval, ttl_check_interval)

    Supervisor.child_spec(
      {ConCache, opts},
      id: child_id
    )
  end

  @spec size(atom()) :: non_neg_integer() | nil
  def size(cache_name) do
    try do
      ConCache.size(cache_name)
    catch
      :exit, _ -> nil
    end
  end

  @spec get(atom(), any()) :: any()
  def get(cache_name, key) do
    try do
      cache_name
      |> ConCache.get(key)
      |> Plausible.Cache.Stats.track(cache_name)
    catch
      :exit, _ ->
        Logger.error("Error retrieving key from '#{inspect(cache_name)}'")
        nil
    end
  end

  @spec get(atom(), any(), (-> any())) :: any()
  def get(cache_name, key, fallback_fn) do
    try do
      cache_name
      |> ConCache.get_or_store(key, fn ->
        {:from_fallback, fallback_fn.()}
      end)
      |> Plausible.Cache.Stats.track(cache_name)
    catch
      :exit, _ ->
        Logger.error("Error retrieving key from '#{inspect(cache_name)}'")
        nil
    end
  end

  @spec put(atom(), any(), any()) :: any()
  def put(cache_name, key, value) do
    try do
      :ok = ConCache.put(cache_name, key, value)
      value
    catch
      :exit, _ ->
        Logger.error("Error putting a key to '#{cache_name}'")
        nil
    end
  end

  @spec put_many(atom(), [any()]) :: :ok
  def put_many(cache_name, items) when is_list(items) do
    try do
      true = :ets.insert(ConCache.ets(cache_name), items)
      :ok
    catch
      :exit, _ ->
        Logger.error("Error putting keys to '#{cache_name}'")
        :ok
    end
  end

  @spec delete(atom(), any()) :: :ok
  def delete(cache_name, key) do
    try do
      ConCache.dirty_delete(cache_name, key)
    catch
      :exit, _ ->
        Logger.error("Error deleting a key in '#{cache_name}'")
        :ok
    end
  end

  @spec keys(atom()) :: Enumerable.t()
  def keys(cache_name) do
    try do
      ets = ConCache.ets(cache_name)

      Stream.resource(
        fn -> :ets.first(ets) end,
        fn
          :"$end_of_table" -> {:halt, nil}
          prev_key -> {[prev_key], :ets.next(ets, prev_key)}
        end,
        fn _ -> :ok end
      )
    catch
      :exit, _ ->
        Logger.error("Error retrieving key from '#{inspect(cache_name)}'")
        []
    end
  end
end
