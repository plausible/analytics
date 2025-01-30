defmodule Plausible.Ingestion.ScrollDepthVisibleAt do
  @moduledoc """
  Module that updates the `scroll_depth_visible_at` column for a site when needed.

  This is called in a hot loop in ingestion, so it:
  1. Only updates the database once per site async (if SiteCache doesn't know about visibility yet)
  2. Does not retry the update if it fails, to be retried on server restart
  """

  require Logger
  alias Plausible.Repo

  import Ecto.Query

  def init() do
    :ets.new(__MODULE__, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])
  end

  def mark_scroll_depth_visible(site_id) do
    if :ets.insert_new(__MODULE__, {site_id}) do
      Task.start(fn -> attempt_update_repo(site_id) end)
    end
  end

  defp attempt_update_repo(site_id) do
    Repo.update_all(
      from(s in Plausible.Site, where: s.id == ^site_id and is_nil(s.scroll_depth_visible_at)),
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
