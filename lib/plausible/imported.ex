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
    from(i in SiteImport, where: i.site_id == ^site.id)
    |> Repo.all()
  end

  def list_complete_imports(site) do
    from(i in SiteImport, where: i.site_id == ^site.id and i.status == ^:completed)
    |> Repo.all()
  end

  def list_complete_import_ids(site) do
    ids =
      from(i in SiteImport,
        where: i.site_id == ^site.id and i.status == ^:completed,
        select: i.id
      )
      |> Repo.all()

    # account for legacy imports as well
    if site.imported_data && site.imported_data.status == "ok" do
      [0 | ids]
    else
      ids
    end
  end

  def get_earliest_import(site) do
    first_import =
      from(i in SiteImport,
        where: i.site_id == ^site.id and i.status == :completed,
        order_by: i.start_date,
        limit: 1
      )
      |> Repo.one()

    # fall back to imported_data for legacy support
    cond do
      first_import ->
        first_import

      site.imported_data && site.imported_data.status == "ok" ->
        site.imported_data

      true ->
        nil
    end
  end

  def delete_imports_for_site(site) do
    Repo.delete_all(from i in SiteImport, where: i.site_id == ^site.id)
  end
end
