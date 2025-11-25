defmodule Plausible.Cache.Warmer do
  @moduledoc """
  A periodic cache warmer.

  Child specification options available:

    * `cache_impl` - module expected to implement `Plausible.Cache` behaviour
    * `interval` - the number of milliseconds for each warm-up cycle
    * `cache_name` - defaults to cache_impl.name() but can be overridden for testing
    * `force_start?` - enforcess process startup for testing, even if it's barred
      by `Plausible.Cache.enabled?`. This is useful for avoiding issues with DB ownership
      and async tests.
    * `warmer_fn` - by convention, either `:refresh_all` or `:refresh_updated_recently`,
      both are automatically provided by `cache_impl` module. Technically any exported
      or captured function will work, if need be.

  See tests for more comprehensive examples.
  """

  @behaviour :gen_cycle

  require Logger

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec() | :ignore
  def child_spec(opts) do
    child_name = Keyword.get(opts, :child_name, __MODULE__)

    %{
      id: child_name,
      start: {:gen_cycle, :start_link, [{:local, child_name}, __MODULE__, opts]}
    }
  end

  @impl true
  def init_cycle(opts) do
    cache_impl = Keyword.fetch!(opts, :cache_impl)
    cache_name = Keyword.get(opts, :cache_name, cache_impl.name())
    interval = Keyword.fetch!(opts, :interval)

    warmer_fn =
      case Keyword.fetch!(opts, :warmer_fn) do
        f when is_function(f, 1) ->
          f

        f when is_atom(f) ->
          true = function_exported?(cache_impl, f, 1)
          Function.capture(cache_impl, f, 1)
      end

    force_start? = Keyword.get(opts, :force_start?, false)

    if Plausible.Cache.enabled?() or force_start? do
      Logger.notice(
        "#{__MODULE__} initializing #{inspect(warmer_fn)} #{cache_name} with interval #{interval}..."
      )

      {:ok,
       {interval,
        opts
        |> Keyword.put(:cache_name, cache_name)
        |> Keyword.put(:warmer_fn, warmer_fn)}}
    else
      :ignore
    end
  end

  @impl true
  def handle_cycle(opts) do
    cache_name = Keyword.fetch!(opts, :cache_name)
    warmer_fn = Keyword.fetch!(opts, :warmer_fn)

    Logger.notice("#{__MODULE__} running #{inspect(warmer_fn)} on #{cache_name}...")

    warmer_fn.(opts)

    {:continue_hibernated, opts}
  end

  @impl true
  def handle_info(_msg, state) do
    {:continue, state}
  end
end
