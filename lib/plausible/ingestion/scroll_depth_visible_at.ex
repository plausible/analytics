defmodule Plausible.Ingestion.ScrollDepthVisibleAt do
  @moduledoc false

  use GenServer
  require Logger
  alias Plausible.Repo

  import Ecto.Query

  @initial_state %{
    updated_sites: MapSet.new(),
    pending: MapSet.new()
  }

  def start_link(opts) do
    opts = Keyword.merge(opts, name: __MODULE__)
    GenServer.start_link(__MODULE__, @initial_state, opts)
  end

  def mark_scroll_depth_visible(site_id) do
    GenServer.cast(__MODULE__, {:update_site, site_id})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:update_site, site_id}, state) do
    cond do
      MapSet.member?(state.updated_sites, site_id) ->
        {:noreply, state}

      MapSet.member?(state.pending, site_id) ->
        {:noreply, state}

      true ->
        Task.start(fn -> attempt_update_repo(site_id) end)

        {:noreply,
         %{
           updated_sites: state.updated_sites,
           pending: MapSet.put(state.pending, site_id)
         }}
    end
  end

  @impl true
  def handle_cast({:mark_updated, site_id}, state) do
    {:noreply,
     %{
       updated_sites: MapSet.put(state.updated_sites, site_id),
       pending: MapSet.delete(state.pending, site_id)
     }}
  end

  @impl true
  def handle_cast({:mark_update_failed, site_id}, state) do
    {:noreply,
     %{
       updated_sites: state.updated_sites,
       pending: MapSet.delete(state.pending, site_id)
     }}
  end

  defp attempt_update_repo(site_id) do
    Repo.update_all(
      from(s in Plausible.Site, where: s.id == ^site_id),
      set: [
        scroll_depth_visible_at: DateTime.utc_now()
      ]
    )

    # Call genserver with {:mark_updated, site_id}
    GenServer.cast(__MODULE__, {:mark_updated, site_id})
  rescue
    error ->
      Logger.error(
        "Error updating scroll depth visible at for site #{site_id}: #{inspect(error)}. Will retry later."
      )

      GenServer.cast(__MODULE__, {:mark_update_failed, site_id})
  end
end
