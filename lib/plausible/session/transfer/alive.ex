defmodule Plausible.Session.Transfer.Alive do
  @moduledoc false
  use GenServer

  @spec start_link(until: (-> boolean)) :: GenServer.on_start()
  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:debug, :name, :spawn_opt, :hibernate_after])
    until = Keyword.fetch!(opts, :until)
    GenServer.start_link(__MODULE__, until, gen_opts)
  end

  @impl true
  def init(until) do
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
