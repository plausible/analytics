defmodule Plausible.Ingestion.ScrollDepthVisibleAt do
  @moduledoc """
  GenServer that updates the `scroll_depth_visible_at` column for a site when needed.

  This is called in a hot loop in ingestion, so it:
  1. Only updates the database once per site (if SiteCache doesn't know about visibility yet)
  2. Does not retry the update if it fails, to be retried on server restart
  """

  use GenServer
  require Logger
  alias Plausible.Repo

  import Ecto.Query

  def start_link(opts \\ []) do
    opts = Keyword.merge(opts, name: __MODULE__)
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def mark_scroll_depth_visible(site_id) do
    GenServer.cast(__MODULE__, {:update_site, site_id})
  end

  @impl true
  def init(_opts) do
    {:ok, MapSet.new()}
  end

  @impl true
  def handle_cast({:update_site, site_id}, touched_sites) do
    # When receiving multiple update requests for a site, only process the first one
    if MapSet.member?(touched_sites, site_id) do
      {:noreply, touched_sites}
    else
      Task.start(fn -> attempt_update_repo(site_id) end)

      {:noreply, MapSet.put(touched_sites, site_id)}
    end
  end

  defp attempt_update_repo(site_id) do
    Repo.update_all(
      from(s in Plausible.Site, where: s.id == ^site_id),
      set: [
        scroll_depth_visible_at: DateTime.utc_now()
      ]
    )
  rescue
    error ->
      Logger.error(
        "Error updating scroll_depth_visible_at for site #{site_id}: #{inspect(error)}. This will not be retried until server restart."
      )
  end
end
