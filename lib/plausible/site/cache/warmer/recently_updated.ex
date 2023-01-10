defmodule Plausible.Site.Cache.Warmer.RecentlyUpdated do
  @moduledoc """
  A Cache.Warmer adapter that only refreshes the Cache
  with recently updated sites every 30 seconds.
  """
  alias Plausible.Site.Cache

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec() | :ignore
  def child_spec(opts) do
    child_name = Keyword.get(opts, :child_name, __MODULE__)

    opts = [
      child_name: child_name,
      interval: :timer.seconds(30),
      warmer_fn: &Cache.refresh_updated_recently/1
    ]

    Plausible.Site.Cache.Warmer.child_spec(opts)
  end
end
