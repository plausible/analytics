defmodule Plausible.Cache do
  @moduledoc """
  Caching interface specific for Plausible. Usage:

      use Plausible.Cache

      # - Implement the callbacks required
      # - Optionally override `unwrap_cache_keys/1`
      # - Populate the cache with `Plausible.Cache.Warmer`

  Serves as a wrapper around `Plausible.Cache.Adapter`, where the underlying
  implementation can be transparently swapped.

  Even though normally the relevant Adapter processes are started, cache access is disabled
  during tests via the `:plausible, #{__MODULE__}, enabled: bool()` application env key.
  This can be overridden on case by case basis, using the child specs options.

  The `base_db_query/0` callback is used to generate the base query that is
  executed on every cache refresh.

  There are two modes of refresh operation: `:all` and `:updated_recently`;
  the former will invoke the query as is and clear all the existing entries,
  while the latter will attempt to limit the query to only the records that
  have been updated in the last 15 minutes and try to merge the new results with
  existing cache entries.

  Both refresh modes are normally executed periodically from within a warmer process;
  see: `Plausible.Cache.Warmer`. The reason for two modes is that the latter is lighter
  on the database and can be executed more frequently.

  When Cache is disabled via application env, the `get/1` function
  falls back to pure database lookups (implemented via `get_from_source/1` callback.
  This should help with introducing cached lookups in existing code,
  so that no existing tests should break.

  Refreshing the cache emits telemetry event defined as per `telemetry_event_refresh/2`.
  """
  @doc "Unique cache name, used by underlying implementation"
  @callback name() :: atom()
  @doc "Supervisor child id, must be unique within the supervision tree"
  @callback child_id() :: atom()
  @doc "Optional repo to use. Defaults to Plausible.Repo"
  @callback repo() :: Ecto.Repo.t()
  @doc "Counts all items at the source, an aggregate query most likely"
  @callback count_all() :: integer()
  @doc "Optionally unwraps the keys of the cache items, in case one item is stored under multiple keys"
  @callback unwrap_cache_keys([any()]) :: [{any(), any()}]
  @doc "Returns the base Ecto query used to refresh the cache"
  @callback base_db_query() :: Ecto.Query.t()
  @doc "Retrieves the item from the source, in case the cache is disabled"
  @callback get_from_source(any()) :: any()

  @doc "Looks for application env value at `:plausible, #{__MODULE__}, enabled: bool()`"
  def enabled?() do
    Application.fetch_env!(:plausible, __MODULE__)[:enabled] == true
  end

  # credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks
  defmacro __using__(_opts) do
    quote do
      @behaviour Plausible.Cache
      @modes [:all, :updated_recently]

      alias Plausible.Cache.Adapter
      require Logger

      @spec get(any(), Keyword.t()) :: any() | nil
      def get(key, opts \\ []) when is_list(opts) do
        cache_name = Keyword.get(opts, :cache_name, name())
        force? = Keyword.get(opts, :force?, false)

        if Plausible.Cache.enabled?() or force? do
          Adapter.get(cache_name, key)
        else
          get_from_source(key)
        end
      end

      @spec get_or_store(any(), (-> any()), Keyword.t()) :: any() | nil
      def get_or_store(key, fallback_fn, opts \\ [])
          when is_function(fallback_fn, 0) and is_list(opts) do
        cache_name = Keyword.get(opts, :cache_name, name())
        force? = Keyword.get(opts, :force?, false)

        if Plausible.Cache.enabled?() or force? do
          Adapter.get(cache_name, key, fallback_fn)
        else
          get_from_source(key) || fallback_fn.()
        end
      end

      def unwrap_cache_keys(items), do: items
      defoverridable unwrap_cache_keys: 1

      def repo(), do: Plausible.Repo
      defoverridable repo: 0

      @spec refresh_all(Keyword.t()) :: :ok
      def refresh_all(opts \\ []) do
        refresh(
          :all,
          base_db_query(),
          Keyword.put(opts, :delete_stale_items?, true)
        )
      end

      @spec refresh_updated_recently(Keyword.t()) :: :ok
      def refresh_updated_recently(opts \\ []) do
        recently_updated_query =
          from [s, ...] in base_db_query(),
            order_by: [asc: s.updated_at],
            where: s.updated_at > ago(^15, "minute")

        refresh(
          :updated_recently,
          recently_updated_query,
          Keyword.put(opts, :delete_stale_items?, false)
        )
      end

      @spec merge_items(new_items :: [any()], opts :: Keyword.t()) :: :ok
      def merge_items(new_items, opts \\ [])
      def merge_items([], _), do: :ok

      def merge_items(new_items, opts) do
        new_items = unwrap_cache_keys(new_items)
        cache_name = Keyword.get(opts, :cache_name, name())
        :ok = Adapter.put_many(cache_name, new_items)

        if Keyword.get(opts, :delete_stale_items?, true) do
          old_keys = Adapter.keys(cache_name)

          new = MapSet.new(Enum.into(new_items, [], fn {k, _} -> k end))
          old = MapSet.new(old_keys)

          old
          |> MapSet.difference(new)
          |> Enum.each(fn k ->
            Adapter.delete(cache_name, k)
          end)
        end

        :ok
      end

      @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
      def child_spec(opts) do
        cache_name = Keyword.get(opts, :cache_name, name())
        child_id = Keyword.get(opts, :child_id, child_id())
        Adapter.child_spec(cache_name, child_id, opts)
      end

      @doc """
      Ensures the cache has non-zero size unless no items exist.
      Useful for orchestrating app startup to prevent the service
      going up asynchronously with an empty cache.
      """
      @spec ready?(atom()) :: boolean
      def ready?(cache_name \\ name()) do
        case size(cache_name) do
          n when is_integer(n) and n > 0 ->
            true

          0 ->
            count_all() == 0

          _ ->
            false
        end
      end

      defdelegate size(cache_name \\ name()), to: Plausible.Cache.Adapter

      @spec telemetry_event_refresh(atom(), atom()) :: list(atom())
      def telemetry_event_refresh(cache_name \\ name(), mode) when mode in @modes do
        [:plausible, :cache, cache_name, :refresh, mode]
      end

      defp refresh(mode, query, opts) when mode in @modes do
        cache_name = Keyword.get(opts, :cache_name, name())

        Plausible.PromEx.Plugins.PlausibleMetrics.measure_duration(
          telemetry_event_refresh(cache_name, mode),
          fn ->
            try do
              items = repo().all(query)
              :ok = merge_items(items, opts)
            catch
              _, e ->
                Logger.error("Error refreshing '#{cache_name}' - #{inspect(e)}")
            end
          end
        )

        :ok
      end
    end
  end
end
