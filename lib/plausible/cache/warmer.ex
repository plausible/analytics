defmodule Plausible.Cache.Warmer do
  @moduledoc """
  A periodic cache warmer.

  Child specification options available:

    * `cache_impl` - module expected to implement `Plausible.Cache` behaviour
    * `interval` - the number of milliseconds for each warm-up cycle
    * `retry_interval` - optional. The number of milliseconds to wait before
      the warmer retries a warm-up that returned `{:error, reason}`. The wait
      doubles after each failed retry, plus up to a third of it at random, so
      warmers that fail together do not retry together. Without this option,
      the warmer does not retry and waits for the next cycle.
    * `max_retries` - defaults to 3. The number of retries before the warmer
      gives up and waits for the next cycle.
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

  @default_max_retries 3

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

      opts =
        opts
        |> Keyword.put(:cache_name, cache_name)
        |> Keyword.put(:warmer_fn, warmer_fn)

      {:ok, {interval, {opts, nil}}}
    else
      :ignore
    end
  end

  @impl true
  def handle_cycle({opts, _retry}) do
    {:continue_hibernated, warm(opts, 0)}
  end

  @impl true
  def handle_info({:retry, ref}, {opts, {ref, retries}}) do
    {:continue_hibernated, warm(opts, retries)}
  end

  def handle_info(_msg, state) do
    {:continue, state}
  end

  defp warm(opts, retries) do
    cache_name = Keyword.fetch!(opts, :cache_name)
    warmer_fn = Keyword.fetch!(opts, :warmer_fn)

    Logger.notice("#{__MODULE__} running #{inspect(warmer_fn)} on #{cache_name}...")

    case warmer_fn.(opts) do
      {:error, reason} -> {opts, schedule_retry(opts, retries + 1, reason)}
      _ -> {opts, nil}
    end
  end

  defp schedule_retry(opts, retry, reason) do
    retry_interval = Keyword.get(opts, :retry_interval)
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    failure = "#{__MODULE__} #{inspect(opts[:warmer_fn])} on #{opts[:cache_name]} failed"

    if retry_interval && retry <= max_retries do
      backoff = retry_interval * Integer.pow(2, retry - 1)
      delay = backoff + Enum.random(0..div(backoff, 3))

      Logger.warning(
        "#{failure}, retrying in #{delay}ms (#{retry}/#{max_retries}) - #{inspect(reason)}"
      )

      ref = make_ref()
      Process.send_after(self(), {:retry, ref}, delay)
      {ref, retry}
    else
      Logger.error("#{failure} - #{inspect(reason)}")
      nil
    end
  end
end
