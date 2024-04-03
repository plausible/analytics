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

  @spec schemas() :: [module()]
  def schemas, do: @tables

  @spec tables() :: [String.t()]
  def tables, do: @table_names

  @spec max_complete_imports() :: non_neg_integer()
  def max_complete_imports(), do: @max_complete_imports

  @spec load_import_data(Site.t()) :: Site.t()
  def load_import_data(%{import_data_loaded: true} = site), do: site

  def load_import_data(site) do
    complete_import_ids = list_complete_import_ids(site)
    dates = get_imports_date_range(site)

    %{
      site
      | import_data_loaded: true,
        earliest_import_start_date: dates.start_date,
        latest_import_end_date: dates.end_date,
        complete_import_ids: complete_import_ids
    }
  end

  @spec get_import(Site.t(), non_neg_integer()) :: SiteImport.t() | nil
  def get_import(site, import_id) do
    Repo.get_by(SiteImport, id: import_id, site_id: site.id)
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
        select: {i.legacy, i.id},
        limit: @max_complete_imports
      )
      |> Repo.all()

    has_legacy? = Enum.any?(ids, fn {legacy?, _} -> legacy? end)
    ids = Enum.map(ids, &elem(&1, 1))

    # account for legacy imports as well
    if has_legacy? || (site.imported_data && site.imported_data.status == "ok") do
      [0 | ids]
    else
      ids
    end
  end

  @spec get_imports_date_range(Site.t()) :: %{
          start_date: Date.t() | nil,
          end_date: Date.t() | nil
        }
  def get_imports_date_range(site) do
    dates =
      from(i in SiteImport,
        where: i.site_id == ^site.id and i.status == ^SiteImport.completed(),
        select: %{start_date: min(i.start_date), end_date: max(i.end_date)}
      )
      |> Repo.one()

    dates = dates || %{start_date: nil, end_date: nil}

    if site.imported_data && site.imported_data.status == "ok" do
      start_date =
        [dates.start_date, site.imported_data.start_date]
        |> Enum.reject(&is_nil/1)
        |> Enum.min(Date, fn -> nil end)

      end_date =
        [dates.end_date, site.imported_data.end_date]
        |> Enum.reject(&is_nil/1)
        |> Enum.max(Date, fn -> nil end)

      %{start_date: start_date, end_date: end_date}
    else
      dates
    end
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
         [_ | _] = free_ranges <- find_free_ranges(start_date, end_date, site) do
      longest = Enum.max_by(free_ranges, &Date.diff(&1.last, &1.first))
      {:ok, longest.first, longest.last}
    else
      _ -> {:error, :no_time_window}
    end
  end

  defp find_free_ranges(start_date, end_date, site) do
    occupied_ranges =
      site
      |> Imported.list_all_imports(Imported.SiteImport.completed())
      |> Enum.reject(&(Date.diff(&1.end_date, &1.start_date) < 2))
      |> Enum.map(&Date.range(&1.start_date, &1.end_date))

    Date.range(start_date, end_date)
    |> free_ranges(start_date, occupied_ranges, [])
  end

  # This function recursively finds open ranges that are not yet occupied
  # by existing imported data. The idea is that we keep moving a dynamic
  # date index `d` from start until the end of `imported_range`, hopping
  # over each occupied range, and capturing the open ranges step-by-step
  # in the `result` array.
  defp free_ranges(import_range, d, [occupied_range | rest_of_occupied_ranges], result) do
    cond do
      Date.diff(occupied_range.last, d) <= 0 ->
        free_ranges(import_range, d, rest_of_occupied_ranges, result)

      in_range?(d, occupied_range) || Date.diff(occupied_range.first, d) < 2 ->
        d = occupied_range.last
        free_ranges(import_range, d, rest_of_occupied_ranges, result)

      true ->
        free_range = Date.range(d, occupied_range.first)
        result = result ++ [free_range]
        d = occupied_range.last
        free_ranges(import_range, d, rest_of_occupied_ranges, result)
    end
  end

  defp free_ranges(import_range, d, [], result) do
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
