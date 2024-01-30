defmodule Plausible.Imported do
  @moduledoc """
  Context for managing site statistics imports.
  """

  import Ecto.Query

  alias Plausible.Imported
  alias Plausible.Imported.SiteImport
  alias Plausible.Repo
  alias Plausible.Site

  @tables [
    Imported.Visitor,
    Imported.Source,
    Imported.Page,
    Imported.EntryPage,
    Imported.ExitPage,
    Imported.Location,
    Imported.Device,
    Imported.Browser,
    Imported.OperatingSystem
  ]

  @table_names Enum.map(@tables, & &1.__schema__(:source))

  @spec tables() :: [String.t()]
  def tables, do: @table_names

  @spec list_all_imports(Site.t()) :: [SiteImport.t()]
  def list_all_imports(site) do
    from(i in SiteImport, where: i.site_id == ^site.id)
    |> Repo.all()
  end

  @spec list_complete_import_ids(Site.t()) :: [non_neg_integer()]
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

  @spec get_earliest_import(Site.t()) :: SiteImport.t() | nil
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

  @spec delete_imports_for_site(Site.t()) :: :ok
  def delete_imports_for_site(site) do
    Repo.delete_all(from i in SiteImport, where: i.site_id == ^site.id)

    :ok
  end
end
