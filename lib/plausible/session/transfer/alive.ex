defmodule Plausible.Session.Transfer.Alive do
  @moduledoc false
  use GenServer

  @spec start_link((-> boolean)) :: GenServer.on_start()
  def start_link(until) do
    {gen_opts, opts} = Keyword.split(opts, [:debug, :name, :spawn_opt, :hibernate_after])
    GenServer.start_link(__MODULE__, until, gen_opts)
  end

  @impl true
  def init(until) when is_function(until, 0) do
    Process.flag(:trap_exit, true)
    {:ok, until}
  end

  @impl true
  def terminate(_reason, until) do
    loop(until)
  end

  defp loop(until) do
    case until.() do
      true ->
        :ok

      false ->
        :timer.sleep(500)
        loop(until)
    end
  end
end
