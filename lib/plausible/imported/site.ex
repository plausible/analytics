defmodule Plausible.Imported do
  @tables ~w(
    imported_visitors imported_sources imported_pages imported_entry_pages
    imported_exit_pages imported_locations imported_devices imported_browsers
    imported_operating_systems
  )
  @spec tables() :: [String.t()]
  def tables, do: @tables

  def forget(site) do
    Plausible.Purge.delete_imported_stats!(site)
  end
end
