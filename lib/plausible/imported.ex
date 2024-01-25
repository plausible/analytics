defmodule Plausible.Imported do
  @moduledoc """
  Context for managing site statistics imports.
  """

  import Ecto.Query

  alias Plausible.Imported.SiteImport
  alias Plausible.Repo

  @tables ~w(
    imported_visitors imported_sources imported_pages imported_entry_pages
    imported_exit_pages imported_locations imported_devices imported_browsers
    imported_operating_systems
  )

  @spec tables() :: [String.t()]
  def tables, do: @tables

  def list_all_imports(site) do
    SiteImport
    |> where(site_id: ^site.id)
    |> Repo.all()
  end

  def list_imports(site) do
    SiteImport
    |> where(site_id: ^site.id, status: :completed)
    |> Repo.all()
  end

  def delete_imports_for_site(site) do
    Repo.delete_all(from i in SiteImport, where: i.site_id == ^site.id)
  end
end
