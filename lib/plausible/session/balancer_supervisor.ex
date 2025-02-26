defmodule Plausible.Session.BalancerSupervisor do
  @moduledoc "Serialize session processing to avoid explicit locks"
  use Supervisor

  if Mix.env() in [:test, :ce_test] do
    def size(),
      do: 10
  else
    def size(), do: 100
  end

  def start_link(_) do
    Supervisor.start_link(__MODULE__, size(), name: __MODULE__)
  end

  def init(size) do
    children =
      for id <- 1..size do
        %{
          id: id,
          start: {Plausible.Session.Balancer, :start_link, [id]},
          restart: :permanent
        }
      end

    Supervisor.init(
      [
        {Registry, [keys: :unique, name: Plausible.Session.Balancer.Registry]} | children
      ],
      strategy: :one_for_one
    )
  end
end
