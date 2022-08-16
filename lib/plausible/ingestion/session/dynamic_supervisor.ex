defmodule Plausible.Ingestion.Session.DynamicSupervisor do
  alias Plausible.Ingestion.Session
  use DynamicSupervisor

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def find_or_spawn(domain, user_id) do
    case Registry.lookup(Session.Registry, {domain, user_id}) do
      [{pid, _}] -> pid
      [] -> spawn_process(domain, user_id)
    end
  end

  defp spawn_process(domain, user_id) do
    child_spec = %{
      id: Session.Actor,
      start: {Session.Actor, :start_link, [{domain, user_id}]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
