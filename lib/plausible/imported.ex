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
    import_range = Date.range(start_date, end_date)

    existing_ranges =
      site
      |> Imported.list_all_imports(Imported.SiteImport.completed())
      |> Enum.map(&build_open_range(&1.start_date, &1.end_date))
      |> Enum.reject(&is_nil/1)

    cropped_ranges = crop_date_range(import_range, existing_ranges)

    if cropped_ranges == [] do
      {:error, :no_time_window}
    else
      longest = Enum.max_by(cropped_ranges, &Date.diff(&1.last, &1.first))

      {:ok, longest.first, longest.last}
    end
  end

  defp build_open_range(start_date, end_date) do
    if Date.diff(end_date, start_date) <= 2 do
      nil
    else
      Date.range(Date.add(start_date, 1), Date.add(end_date, -1))
    end
  end

  defp crop_date_range(range, cropping_ranges) do
    cropping_ranges
    |> Enum.map(&Enum.to_list/1)
    |> Enum.reduce(Enum.to_list(range), fn existing, dates ->
      dates -- existing
    end)
    |> Enum.reduce([], fn
      date, [] ->
        [date]

      date, [%Date{} = prev_date | rest] ->
        if Date.diff(date, prev_date) == 1 do
          [Date.range(prev_date, date) | rest]
        else
          [date, Date.range(prev_date, prev_date) | rest]
        end

      date, [%Date.Range{} = range | rest] ->
        if Date.diff(date, range.last) == 1 do
          [Date.range(range.first, date) | rest]
        else
          [date, range | rest]
        end
    end)
    |> finalize_crop()
    |> Enum.reject(&(Date.diff(&1.last, &1.first) < 1))
  end

  defp finalize_crop([%Date{} = date | rest]), do: [Date.range(date, date) | rest]
  defp finalize_crop(other), do: other
end
