defmodule Plausible.Session.Balancer do
  @moduledoc "Serialize session processing to avoid explicit locks"
  use GenServer

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: via(id))
  end

  @impl true
  def init(id) do
    {:ok, %{id: id}}
  end

  def dispatch(user_id, fun, opts) do
    timeout = Keyword.fetch!(opts, :timeout)
    local? = Keyword.get(opts, :local?, false)

    if local? do
      fun.()
    else
      worker = :erlang.phash2(user_id, Plausible.Session.BalancerSupervisor.size()) + 1
      [{pid, _}] = Registry.lookup(Plausible.Session.Balancer.Registry, worker)
      GenServer.call(pid, {:process, fun}, timeout)
    end
  end

  @impl true
  def handle_call({:process, fun}, _from, state) do
    try do
      response = fun.()
      {:reply, response, state}
    rescue
      e ->
        {:reply, {:error, e}, state}
    end
  end

  defp via(id), do: {:via, Registry, {Plausible.Session.Balancer.Registry, id}}
end
