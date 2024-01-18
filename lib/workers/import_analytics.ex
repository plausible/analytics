defmodule Plausible.Workers.ImportAnalytics do
  @moduledoc """
  Worker for running analytics import jobs.
  """

  use Plausible.Repo
  require Logger

  use Oban.Worker,
    queue: :analytics_imports,
    max_attempts: 3,
    unique: [fields: [:args], period: 60]

  alias Plausible.Imported.ImportSources

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"site_id" => site_id, "source" => source} = args
      }) do
    import_api = ImportSources.by_name(source)
    import_opts = import_api.parse_args(args)

    site = Repo.get!(Plausible.Site, site_id)

    case import_api.import(site, import_opts) do
      :ok ->
        import_success(source, site)

        :ok

      {:error, error} ->
        Sentry.capture_message("Failed to import from Google Analytics",
          extra: %{site: site.domain, error: inspect(error)}
        )

        import_failed(source, site)

        {:error, error}
    end
  end

  @impl Oban.Worker
  def backoff(_job) do
    # 5 minutes
    300
  end

  def import_success(source, site) do
    site = Repo.preload(site, memberships: :user)

    site
    |> Plausible.Site.import_success()
    |> Repo.update!()

    Enum.each(site.memberships, fn membership ->
      if membership.role in [:owner, :admin] do
        PlausibleWeb.Email.import_success(source, membership.user, site)
        |> Plausible.Mailer.send()
      end
    end)
  end

  def import_failed(source, site) do
    site = Repo.preload(site, memberships: :user)

    site
    |> Plausible.Site.import_failure()
    |> Repo.update!()

    Plausible.Purge.delete_imported_stats!(site)

    Enum.each(site.memberships, fn membership ->
      if membership.role in [:owner, :admin] do
        PlausibleWeb.Email.import_failure(source, membership.user, site)
        |> Plausible.Mailer.send()
      end
    end)
  end
end
