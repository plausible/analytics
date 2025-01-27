defmodule Plausible.Imported do
  @moduledoc """
  Context for managing site statistics imports.

  For list of currently supported import sources see `Plausible.Imported.ImportSources`.

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
    Imported.CustomEvent,
    Imported.Location,
    Imported.Device,
    Imported.Browser,
    Imported.OperatingSystem
  ]

  @table_names Enum.map(@tables, & &1.__schema__(:source))
  # Maximum number of complete imports to account for when querying stats
  @max_complete_imports 5

  # Goals which can be filtered by url property
  @goals_with_url ["Outbound Link: Click", "Cloaked Link: Click", "File Download"]
  # Goals which can be filtered by path property
  @goals_with_path ["404", "WP Form Completions"]

  @spec schemas() :: [module()]
  def schemas, do: @tables

  @spec tables() :: [String.t()]
  def tables, do: @table_names

  @spec max_complete_imports() :: non_neg_integer()
  def max_complete_imports() do
    @max_complete_imports
  end

  @spec imported_custom_props() :: [String.t()]
  def imported_custom_props do
    # NOTE: Keep up to date with `Plausible.Props.internal_keys/1`,
    # but _ignore_ unsupported keys. Currently, `search_query` is
    # not supported in imported queries.
    Enum.map(~w(url path), &("event:props:" <> &1))
  end

  @spec goals_with_url() :: [String.t()]
  def goals_with_url() do
    @goals_with_url
  end

  @spec goals_with_path() :: [String.t()]
  def goals_with_path() do
    @goals_with_path
  end

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

  @spec get_legacy_import(Site.t()) :: SiteImport.t() | nil
  def get_legacy_import(site) do
    from(i in SiteImport,
      where: i.site_id == ^site.id and i.legacy == true,
      order_by: [desc: i.updated_at],
      limit: 1
    )
    |> Repo.one()
  end

  defdelegate listen(), to: Imported.Importer

  @spec list_all_imports(Site.t(), atom()) :: [SiteImport.t()]
  def list_all_imports(site, status \\ nil) do
    from(i in SiteImport, where: i.site_id == ^site.id, order_by: [desc: i.inserted_at])
    |> maybe_filter_by_status(status)
    |> Repo.all()
  end

  @spec other_imports_in_progress?(SiteImport.t()) :: boolean()
  def other_imports_in_progress?(site_import) do
    Repo.exists?(
      from(i in SiteImport,
        where: i.site_id == ^site_import.site_id and i.id != ^site_import.id,
        where: i.status in ^[SiteImport.pending(), SiteImport.importing()]
      )
    )
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
    if has_legacy? do
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

    dates || %{start_date: nil, end_date: nil}
  end

  @spec delete_imports_for_site(Site.t()) :: :ok
  def delete_imports_for_site(site) do
    Repo.delete_all(from i in SiteImport, where: i.site_id == ^site.id)

    :ok
  end

  @spec clamp_dates(Site.t(), Date.t(), Date.t()) ::
          {:ok, Date.t(), Date.t()} | {:error, :no_time_window}
  def clamp_dates(site, start_date, end_date) do
    cutoff_date = get_cutoff_date(site)
    occupied_ranges = get_occupied_date_ranges(site)

    clamp_dates(occupied_ranges, cutoff_date, start_date, end_date)
  end

  @spec clamp_dates([Date.Range.t()], Date.t(), Date.t(), Date.t()) ::
          {:ok, Date.t(), Date.t()} | {:error, :no_time_window}
  def clamp_dates(occupied_ranges, cutoff_date, start_date, end_date) do
    end_date = Enum.min([end_date, cutoff_date], Date)

    with true <- Date.diff(end_date, start_date) >= 2,
         [_ | _] = free_ranges <- find_free_ranges(start_date, end_date, occupied_ranges) do
      longest = Enum.max_by(free_ranges, &Date.diff(&1.last, &1.first))
      {:ok, longest.first, longest.last}
    else
      _ -> {:error, :no_time_window}
    end
  end

  @spec get_occupied_date_ranges(Site.t()) :: [Date.Range.t()]
  def get_occupied_date_ranges(site) do
    site
    |> Imported.list_all_imports(Imported.SiteImport.completed())
    |> Enum.reject(&(Date.diff(&1.end_date, &1.start_date) < 2))
    |> Enum.map(&Date.range(&1.start_date, &1.end_date))
    |> Enum.sort_by(& &1.first, Date)
  end

  @spec get_cutoff_date(Site.t()) :: Date.t()
  def get_cutoff_date(site) do
    Plausible.Sites.native_stats_start_date(site) ||
      DateTime.to_date(DateTime.now!(site.timezone))
  end

  defp find_free_ranges(start_date, end_date, occupied_ranges) do
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
