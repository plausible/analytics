defmodule Plausible.Cache.Adapter do
  @moduledoc """
  Interface for the underlying cache implementation.
  Currently: ConCache

  Using the Adapter module directly, the user must ensure that the relevant
  processes are available to use, which is normally done via the child specification.
  """

  require Logger

  @spec child_specs(atom(), atom(), Keyword.t()) :: [Supervisor.child_spec()]
  def child_specs(name, child_id, opts \\ [])
      when is_atom(name) and is_atom(child_id) and is_list(opts) do
    partitions = partitions(name)

    if partitions == 1 do
      [child_spec(name, child_id, opts)]
    else
      Enum.map(1..partitions, fn partition ->
        partition_name = String.to_atom("#{name}_#{partition}")
        partition_child_id = String.to_atom("#{child_id}_#{partition}")

        child_spec(partition_name, partition_child_id, opts)
      end)
    end
  end

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
    cache_name
    |> get_names()
    |> Enum.map(&ConCache.size/1)
    |> Enum.sum()
  catch
    :exit, _ -> nil
  end

  @spec get(atom(), any()) :: any()
  def get(cache_name, key) do
    full_cache_name = get_name(cache_name, key)
    ConCache.get(full_cache_name, key)
  catch
    :exit, _ ->
      Logger.error("Error retrieving key from '#{inspect(cache_name)}'")
      nil
  end

  @spec get(atom(), any(), (-> any())) :: any()
  def get(cache_name, key, fallback_fn) do
    full_cache_name = get_name(cache_name, key)
    ConCache.get_or_store(full_cache_name, key, fallback_fn)
  catch
    :exit, _ ->
      Logger.error("Error retrieving key from '#{inspect(cache_name)}'")
      nil
  end

  @spec fetch(atom(), any(), (-> any())) :: any()
  def fetch(cache_name, key, fallback_fn) do
    full_cache_name = get_name(cache_name, key)
    ConCache.fetch_or_store(full_cache_name, key, fallback_fn)
  catch
    :exit, _ ->
      Logger.error("Error fetching key from '#{inspect(cache_name)}'")
      nil
  end

  @spec put(atom(), any(), any()) :: any()
  def put(cache_name, key, value, opts \\ []) do
    full_cache_name = get_name(cache_name, key)

    if opts[:dirty?] do
      :ok = ConCache.dirty_put(full_cache_name, key, value)
    else
      :ok = ConCache.put(full_cache_name, key, value)
    end

    value
  catch
    :exit, _ ->
      Logger.error("Error putting a key to '#{cache_name}'")
      nil
  end

  @spec put_many(atom(), [any()]) :: :ok
  def put_many(cache_name, items) when is_list(items) do
    items
    |> Enum.group_by(fn {key, _} -> get_name(cache_name, key) end)
    |> Enum.each(fn {full_cache_name, items} ->
      true = :ets.insert(ConCache.ets(full_cache_name), items)
    end)

    :ok
  catch
    :exit, _ ->
      Logger.error("Error putting keys to '#{cache_name}'")
      :ok
  end

  @spec delete(atom(), any()) :: :ok
  def delete(cache_name, key) do
    full_cache_name = get_name(cache_name, key)
    ConCache.dirty_delete(full_cache_name, key)
  catch
    :exit, _ ->
      Logger.error("Error deleting a key in '#{cache_name}'")
      :ok
  end

  @spec keys(atom()) :: Enumerable.t()
  def keys(cache_name) do
    cache_name
    |> get_names()
    |> Enum.reduce([], fn full_cache_name, stream ->
      Stream.concat(stream, get_keys(full_cache_name))
    end)
  catch
    :exit, _ ->
      Logger.error("Error retrieving key from '#{inspect(cache_name)}'")
      []
  end

  @spec with_lock(atom(), any(), pos_integer(), (-> result)) :: {:ok, result} | {:error, :timeout}
        when result: any()
  def with_lock(cache_name, key, timeout, fun) do
    full_cache_name = get_name(cache_name, key)
    result = ConCache.isolated(full_cache_name, key, timeout, fun)
    {:ok, result}
  catch
    :exit, {:timeout, _} ->
      Sentry.capture_message(
        "Timeout while executing with lock on key in '#{inspect(cache_name)}'",
        extra: %{key: key}
      )

      {:error, :timeout}
  end

  @spec get_names(atom()) :: [atom()]
  def get_names(cache_name) do
    partitions = partitions(cache_name)

    if partitions == 1 do
      [cache_name]
    else
      Enum.map(1..partitions, &String.to_existing_atom("#{cache_name}_#{&1}"))
    end
  end

  defp get_keys(full_cache_name) do
    ets = ConCache.ets(full_cache_name)

    Stream.resource(
      fn -> :ets.first(ets) end,
      fn
        :"$end_of_table" -> {:halt, nil}
        prev_key -> {[prev_key], :ets.next(ets, prev_key)}
      end,
      fn _ -> :ok end
    )
  end

  defp get_name(cache_name, key) do
    partitions = partitions(cache_name)

    if partitions == 1 do
      cache_name
    else
      chosen_partition = :erlang.phash2(key, partitions) + 1
      String.to_existing_atom("#{cache_name}_#{chosen_partition}")
    end
  end

  defp partitions(cache_name) do
    Application.get_env(:plausible, __MODULE__)[cache_name][:partitions] || 1
  end
end
