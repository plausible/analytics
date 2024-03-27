defmodule Plausible.Imported do
  @moduledoc """
  Context for managing site statistics imports.

  Currently following importers are implemented:

  * `Plausible.Imported.UniversalAnalytics` - existing mechanism, for legacy Google
    analytics formerly known as "Google Analytics"
  * `Plausible.Imported.NoopImporter` - importer stub, used mainly for testing purposes
  * `Plausible.Imported.CSVImporter` - CSV importer from S3

  For more information on implementing importers, see `Plausible.Imported.Importer`.
  """

  import Ecto.Query

  alias Plausible.Imported
  alias Plausible.Imported.SiteImport
  alias Plausible.Repo
  alias Plausible.Site

  require Plausible.Imported.SiteImport

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
  # Maximum number of complete imports to account for when querying stats
  @max_complete_imports 5

  @spec tables() :: [String.t()]
  def tables, do: @table_names

  @spec max_complete_imports() :: non_neg_integer()
  def max_complete_imports(), do: @max_complete_imports

  @spec load_import_data(Site.t()) :: Site.t()
  def load_import_data(%{import_data_loaded: true} = site), do: site

  def load_import_data(site) do
    complete_import_ids = list_complete_import_ids(site)
    earliest_import = get_earliest_import(site) || %{}

    %{
      site
      | import_data_loaded: true,
        earliest_import_start_date: Map.get(earliest_import, :start_date),
        earliest_import_end_date: Map.get(earliest_import, :end_date),
        complete_import_ids: complete_import_ids
    }
  end

  @spec get_import(non_neg_integer()) :: SiteImport.t() | nil
  def get_import(import_id) do
    Repo.get(SiteImport, import_id)
  end

  defdelegate listen(), to: Imported.Importer

  @spec list_all_imports(Site.t(), atom()) :: [SiteImport.t()]
  def list_all_imports(site, status \\ nil) do
    imports =
      from(i in SiteImport, where: i.site_id == ^site.id, order_by: [desc: i.inserted_at])
      |> maybe_filter_by_status(status)
      |> Repo.all()

    if site.imported_data && not Enum.any?(imports, & &1.legacy) do
      imports ++ [SiteImport.from_legacy(site.imported_data)]
    else
      imports
    end
  end

  defp maybe_filter_by_status(query, nil), do: query

  defp maybe_filter_by_status(query, status) do
    where(query, [i], i.status == ^status)
  end

  @spec list_complete_import_ids(Site.t()) :: [non_neg_integer()]
  def list_complete_import_ids(site) do
    ids =
      from(i in SiteImport,
        where: i.site_id == ^site.id and i.status == ^SiteImport.completed(),
        select: i.id,
        limit: @max_complete_imports
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
        where: i.site_id == ^site.id and i.status == ^SiteImport.completed(),
        order_by: i.start_date,
        limit: 1
      )
      |> Repo.one()

    legacy_import =
      if site.imported_data && site.imported_data.status == "ok" do
        site.imported_data
      end

    [legacy_import, first_import]
    |> Enum.reject(&is_nil/1)
    |> Enum.min_by(& &1.start_date, Date, fn -> nil end)
  end

  @spec delete_imports_for_site(Site.t()) :: :ok
  def delete_imports_for_site(site) do
    Repo.delete_all(from i in SiteImport, where: i.site_id == ^site.id)

    :ok
  end

  @spec check_dates(Site.t(), Date.t() | nil, Date.t() | nil) ::
          {:ok, Date.t(), Date.t()} | {:error, :no_data | :no_time_window}
  def check_dates(_site, nil, _end_date), do: {:error, :no_data}

  def check_dates(site, start_date, end_date) do
    cutoff_date = Plausible.Sites.native_stats_start_date(site) || Timex.today(site.timezone)
    end_date = Enum.min([end_date, cutoff_date], Date)

    with true <- Date.diff(end_date, start_date) >= 2,
         [_ | _] = open_ranges <- find_open_ranges(start_date, end_date, site) do
      longest = Enum.max_by(open_ranges, &Date.diff(&1.last, &1.first))
      {:ok, longest.first, longest.last}
    else
      _ -> {:error, :no_time_window}
    end
  end

  defp find_open_ranges(start_date, end_date, site) do
    occupied_ranges =
      site
      |> Imported.list_all_imports(Imported.SiteImport.completed())
      |> Enum.reject(&(Date.diff(&1.end_date, &1.start_date) < 2))
      |> Enum.map(&Date.range(&1.start_date, &1.end_date))

    Date.range(start_date, end_date)
    |> open_ranges(start_date, occupied_ranges, [])
  end

  # This function recursively finds open ranges that are not yet occupied
  # by existing imported data. The idea is that we keep moving a dynamic
  # date index `d` from start until the end of `imported_range`, hopping
  # over each occupied range, and capturing the open ranges step-by-step
  # in the `result` array.
  defp open_ranges(import_range, d, [occupied_range | rest_of_occupied_ranges], result) do
    cond do
      Date.diff(occupied_range.last, d) <= 0 ->
        open_ranges(import_range, d, rest_of_occupied_ranges, result)

      in_range?(d, occupied_range) || Date.diff(occupied_range.first, d) < 2 ->
        d = occupied_range.last
        open_ranges(import_range, d, rest_of_occupied_ranges, result)

      true ->
        open_range = Date.range(d, occupied_range.first)
        result = result ++ [open_range]
        d = occupied_range.last
        open_ranges(import_range, d, rest_of_occupied_ranges, result)
    end
  end

  defp open_ranges(import_range, d, [], result) do
    if Date.diff(import_range.last, d) < 2 do
      result
    else
      result ++ [Date.range(d, import_range.last)]
    end
  end

  defp in_range?(date, range) do
    Date.before?(range.first, date) && Date.after?(range.last, date)
  end
end
