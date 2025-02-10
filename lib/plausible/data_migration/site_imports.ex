defmodule Plausible.DataMigration.SiteImports do
  @moduledoc """
  !!!WARNING!!!: This script is used in migrations. Please take special care
  when altering it.

  Site imports migration backfilling SiteImport entries for old imports
  and alters import end dates to match actual end date of respective import stats.
  """

  import Ecto.Query

  alias Plausible.{Repo, ClickhouseRepo, Site}

  defmodule SiteImportSnapshot do
    @moduledoc """
    A snapshot of the Plausible.Imported.SiteImport schema from April 2024.
    """

    use Ecto.Schema

    schema "site_imports" do
      field :start_date, :date
      field :end_date, :date
      field :label, :string
      field :source, Ecto.Enum, values: [:universal_analytics, :google_analytics_4, :csv, :noop]
      field :status, Ecto.Enum, values: [:pending, :importing, :completed, :failed]
      field :legacy, :boolean, default: false

      belongs_to :site, Plausible.Site
      belongs_to :imported_by, Plausible.Auth.User

      timestamps()
    end
  end

  @imported_tables_april_2024 [
    "imported_visitors",
    "imported_sources",
    "imported_pages",
    "imported_entry_pages",
    "imported_exit_pages",
    "imported_custom_events",
    "imported_locations",
    "imported_devices",
    "imported_browsers",
    "imported_operating_systems"
  ]

  def imported_tables_april_2024(), do: @imported_tables_april_2024

  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, true)

    site_import_query =
      from(i in SiteImportSnapshot,
        where: i.site_id == parent_as(:site).id and i.status == ^:completed,
        select: 1
      )

    sites_with_only_legacy_import =
      from(s in Site,
        as: :site,
        select: %{id: s.id, imported_data: s.imported_data},
        where:
          not is_nil(s.imported_data) and fragment("?->>'status'", s.imported_data) == "ok" and
            not exists(site_import_query)
      )
      |> Repo.all(log: false)

    site_imports =
      from(i in SiteImportSnapshot, where: i.status == ^:completed)
      |> Repo.all(log: false)

    legacy_site_imports = backfill_legacy_site_imports(sites_with_only_legacy_import, dry_run?)

    all_site_imports = Repo.preload(site_imports ++ legacy_site_imports, :site)

    adjust_site_import_end_dates(all_site_imports, dry_run?)

    IO.puts("Finished")
  end

  defp backfill_legacy_site_imports(sites, dry_run?) do
    total = length(sites)

    IO.puts("Backfilling legacy site import across #{total} sites (DRY RUN: #{dry_run?})...")

    legacy_site_imports =
      for {site, idx} <- Enum.with_index(sites) do
        IO.puts("Creating legacy site import entry for site ID #{site.id} (#{idx + 1}/#{total})")

        params =
          site.imported_data
          |> from_legacy()
          |> Map.put(:site_id, site.id)
          |> Map.take([:legacy, :start_date, :end_date, :source, :status, :site_id])

        %SiteImportSnapshot{}
        |> Ecto.Changeset.change(params)
        |> insert!(dry_run?)
      end

    IO.puts("Finished backfilling sites.")

    legacy_site_imports
  end

  defp adjust_site_import_end_dates(site_imports, dry_run?) do
    total = length(site_imports)

    IO.puts("Adjusting end dates of #{total} site imports (DRY RUN: #{dry_run?})...")

    for {site_import, idx} <- Enum.with_index(site_imports) do
      IO.puts(
        "Adjusting end date for site import #{site_import.id} (#{idx + 1}/#{total}) (site ID #{site_import.site_id}, start date: #{site_import.start_date}, end date: #{site_import.end_date})"
      )

      import_ids =
        if site_import.legacy do
          [0, site_import.id]
        else
          [site_import.id]
        end

      end_date = imported_stats_end_date(site_import.site_id, import_ids)

      if !end_date do
        IO.puts(
          "Site import #{site_import.id} (site ID #{site_import.site_id}) does not have any recorded stats. Removing it."
        )

        if site_import.legacy do
          # sanity check that data is correct
          "ok" = site_import.site.imported_data.status

          clear_imported_data(site_import.site, dry_run?)
        end

        delete!(site_import, dry_run?)
      else
        case Date.compare(end_date, site_import.end_date) do
          :lt ->
            IO.puts(
              "End date of site import #{site_import.id} (site ID #{site_import.site_id}) is adjusted from #{site_import.end_date} to #{end_date}."
            )

            site_import
            |> Ecto.Changeset.change(end_date: end_date)
            |> update!(dry_run?)

            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            if site_import.legacy do
              # sanity check that data is correct
              "ok" = site_import.site.imported_data.status

              site_import.site
              |> Ecto.Changeset.change(imported_data: %{end_date: end_date})
              |> update!(dry_run?)
            end

          :eq ->
            IO.puts(
              "End date of site import #{site_import.id} (site ID #{site_import.site_id}) is left unadjusted."
            )

          :gt ->
            IO.puts(
              "Site import #{site_import.id} (site ID #{site_import.site_id}) computed end date is later than the current one. Skipping."
            )
        end
      end
    end

    IO.puts("Finished adjusting end dates of site imports.")
  end

  # Exposed for testing purposes
  @doc false
  def imported_stats_end_date(site_id, import_ids) do
    [first_table | tables] = @imported_tables_april_2024

    query =
      Enum.reduce(tables, max_date_query(first_table, site_id, import_ids), fn table, query ->
        from(s in subquery(union_all(query, ^max_date_query(table, site_id, import_ids))))
      end)

    dates = ClickhouseRepo.all(from(q in query, select: q.max_date), log: false)

    if dates != [] do
      case Enum.max(dates, Date) do
        # no stats for this domain yet
        ~D[1970-01-01] ->
          nil

        date ->
          date
      end
    else
      nil
    end
  end

  defp insert!(changeset, false = _dry_run?) do
    Repo.insert!(changeset)
  end

  defp insert!(changeset, true = _dry_run?) do
    if changeset.valid? do
      changeset
      |> Ecto.Changeset.change(id: 0)
      |> Ecto.Changeset.apply_changes()
    else
      raise "Invalid insert: #{inspect(changeset)}"
    end
  end

  defp clear_imported_data(site, false = _dry_run?) do
    Repo.update_all(from(s in Site, where: s.id == ^site.id), set: [imported_data: nil])
  end

  defp clear_imported_data(site, true = _dry_run?) do
    %{site | imported_data: nil}
  end

  defp update!(changeset, false = _dry_run?) do
    Repo.update!(changeset)
  end

  defp update!(changeset, true = _dry_run?) do
    if changeset.valid? do
      Ecto.Changeset.apply_changes(changeset)
    else
      raise "Invalid update: #{inspect(changeset)}"
    end
  end

  defp delete!(entity, false = _dry_run?) do
    Repo.delete!(entity)
  end

  defp delete!(entity, true = _dry_run?) do
    entity
  end

  defp max_date_query(table, site_id, import_ids) do
    from(q in table,
      where: q.site_id == ^site_id,
      where: q.import_id in ^import_ids,
      select: %{max_date: fragment("max(?)", q.date)}
    )
  end

  defp from_legacy(%Site.ImportedData{} = data) do
    status =
      case data.status do
        "ok" -> :completed
        "error" -> :failed
        _ -> :importing
      end

    %SiteImportSnapshot{
      id: 0,
      legacy: true,
      start_date: data.start_date,
      end_date: data.end_date,
      source: :universal_analytics,
      status: status
    }
  end
end
