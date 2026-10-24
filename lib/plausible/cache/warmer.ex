defmodule Plausible.Cache.Warmer do
  @moduledoc """
  A periodic cache warmer.

  Child specification options available:

    * `cache_impl` - module expected to implement `Plausible.Cache` behaviour
    * `interval` - the number of milliseconds for each warm-up cycle
    * `retry_interval` - the number of milliseconds to wait before retrying
      a warm-up that returned `{:error, reason}`, defaults to 30 seconds.
      Retries only happen when this is shorter than `interval`.
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

  @default_retry_interval :timer.seconds(30)

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
    {:continue_hibernated, warm(opts)}
  end

  @impl true
  def handle_info(:retry, opts) do
    {:continue, warm(Keyword.delete(opts, :retry_timer))}
  end

  def handle_info(_msg, state) do
    {:continue, state}
  end

  defp warm(opts) do
    cache_name = Keyword.fetch!(opts, :cache_name)
    warmer_fn = Keyword.fetch!(opts, :warmer_fn)

    opts = cancel_retry(opts)

    Logger.notice("#{__MODULE__} running #{inspect(warmer_fn)} on #{cache_name}...")

    case warmer_fn.(opts) do
      {:error, _} -> maybe_schedule_retry(opts)
      _ -> opts
    end
  end

  defp maybe_schedule_retry(opts) do
    interval = Keyword.fetch!(opts, :interval)
    retry_interval = Keyword.get(opts, :retry_interval, @default_retry_interval)

    if retry_interval < interval do
      Logger.notice(
        "#{__MODULE__} retrying #{inspect(opts[:warmer_fn])} on #{opts[:cache_name]} in #{retry_interval}ms..."
      )

      Keyword.put(opts, :retry_timer, Process.send_after(self(), :retry, retry_interval))
    else
      opts
    end
  end

  defp cancel_retry(opts) do
    case Keyword.pop(opts, :retry_timer) do
      {nil, opts} ->
        opts

      {timer, opts} ->
        if Process.cancel_timer(timer) == false do
          receive do
            :retry -> :ok
          after
            0 -> :ok
          end
        end

        opts
    end
  end
end
