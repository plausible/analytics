defmodule Plausible.RateLimit do
  @moduledoc """
  Thin wrapper around `:ets.update_counter/4` and a
  clean-up process to act as a rate limiter.
  """

  use GenServer

  @doc """
  Starts the process that creates and cleans the ETS table.

  Accepts the following options:
    - `GenServer.option()`
    - `:table` for the ETS table name, defaults to `#{__MODULE__}`
    - `:clean_period` for how often to perform garbage collection
  """
  @spec start_link([GenServer.option() | {:table, atom} | {:clean_period, pos_integer}]) ::
          GenServer.on_start()
  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:debug, :name, :spawn_opt, :hibernate_after])
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Checks the rate-limit for a key.
  """
  @spec check_rate(:ets.table(), key, scale, limit, increment) :: {:allow, count} | {:deny, limit}
        when key: term,
             scale: pos_integer,
             limit: pos_integer,
             increment: pos_integer,
             count: pos_integer
  def check_rate(table \\ __MODULE__, key, scale, limit, increment \\ 1) do
    bucket = div(now(), scale)
    full_key = {key, bucket}
    expires_at = (bucket + 1) * scale

    count =
      case :ets.lookup(table, full_key) do
        [{_, counter, _expires_at}] ->
          :atomics.add_get(counter, 1, increment)

        [] ->
          counter = :atomics.new(1, signed: false)

          case :ets.insert_new(table, {full_key, counter, expires_at}) do
            true ->
              :atomics.add_get(counter, 1, increment)

            false ->
              [{_, counter, _expires_at}] = :ets.lookup(table, full_key)
              :atomics.add_get(counter, 1, increment)
          end
      end

    if count <= limit, do: {:allow, count}, else: {:deny, limit}
  end

  @impl true
  def init(opts) do
    clean_period = Keyword.fetch!(opts, :clean_period)
    table = Keyword.get(opts, :table, __MODULE__)

    ^table =
      :ets.new(table, [
        :named_table,
        :set,
        :public,
        {:read_concurrency, true},
        {:write_concurrency, :auto},
        {:decentralized_counters, true}
      ])

    schedule(clean_period)
    {:ok, %{table: table, clean_period: clean_period}}
  end

  @impl true
  def handle_info(:clean, state) do
    clean(state.table)
    schedule(state.clean_period)
    {:noreply, state}
  end

  defp schedule(clean_period) do
    Process.send_after(self(), :clean, clean_period)
  end

  defp clean(table) do
    ms = [{{{:_, :_}, :_, :"$1"}, [], [{:<, :"$1", {:const, now()}}]}]
    :ets.select_delete(table, ms)
  end

  @compile inline: [now: 0]
  defp now do
    System.system_time(:millisecond)
  end
end
