defmodule Plausible.Workers.ImportAnalytics do
  @moduledoc """
  Worker for running analytics import jobs.
  """

  use Plausible.Repo
  require Logger

  use Oban.Worker,
    queue: :analytics_imports,
    max_attempts: 3,
    unique: [fields: [:args], keys: [:import_id], period: 60]

  alias Plausible.Imported.ImportSources
  alias Plausible.Imported.Importer
  alias Plausible.Imported.SiteImport

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"import_id" => import_id} = args
      }) do
    site_import =
      SiteImport
      |> Repo.get!(import_id)
      |> Repo.preload(:site)

    import_api = ImportSources.by_name(site_import.source)

    case import_api.run_import(site_import, args) do
      {:ok, site_import} ->
        import_complete(site_import)

        :ok

      {:error, error, error_opts} ->
        Logger.error("Failed to import from #{site_import.source}",
          sentry: %{
            extra: %{
              import_id: site_import.id,
              site: site_import.site.domain,
              error: inspect(error)
            }
          }
        )

        import_fail(site_import, error_opts)

        {:discard, error}
    end
  end

  @impl Oban.Worker
  def backoff(_job) do
    # 5 minutes
    300
  end

  def import_complete(site_import) do
    site_import = Repo.preload(site_import, [:site, :imported_by])

    PlausibleWeb.Email.import_success(site_import, site_import.imported_by)
    |> Plausible.Mailer.send()

    Plausible.Sites.clear_stats_start_date!(site_import.site)

    Importer.notify(site_import, :complete)

    :ok
  end

  def import_fail_transient(site_import) do
    Plausible.Purge.delete_imported_stats!(site_import)

    Importer.notify(site_import, :transient_fail)
  end

  def import_fail(site_import, opts) do
    skip_purge? = Keyword.get(opts, :skip_purge?, false)
    skip_mark_failed? = Keyword.get(opts, :skip_mark_failed?, false)

    if not skip_purge? do
      Plausible.Purge.delete_imported_stats!(site_import)
    end

    if not skip_mark_failed? do
      import_api = ImportSources.by_name(site_import.source)

      site_import =
        site_import
        |> import_api.mark_failed()
        |> Repo.preload([:site, :imported_by])

      Importer.notify(site_import, :fail)

      PlausibleWeb.Email.import_failure(site_import, site_import.imported_by)
      |> Plausible.Mailer.send()
    end
  end
end
