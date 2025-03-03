defmodule Plausible.PromEx.StripedPeep do
  @moduledoc """
  "Striped" storage based on `PromEx.Storage.Peep`.
  """

  @behaviour PromEx.Storage

  @impl true
  def scrape(name) do
    Peep.get_all_metrics(name)
    |> Peep.Prometheus.export()
    |> IO.iodata_to_binary()
  end

  @impl true
  def child_spec(name, metrics) do
    opts = [
      name: name,
      metrics: metrics,
      storage: :striped
    ]

    Peep.child_spec(opts)
  end
end
