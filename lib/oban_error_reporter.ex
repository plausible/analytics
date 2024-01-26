defmodule ObanErrorReporter do
  def handle_event([:oban, :job, :exception], measure, %{job: job} = meta, _) do
    extra =
      job
      |> Map.take([:id, :args, :meta, :queue, :worker])
      |> Map.merge(measure)

    on_job_exception(job)

    Sentry.capture_exception(meta.reason, stacktrace: meta.stacktrace, extra: extra)
  end

  def handle_event([:oban, :notifier, :exception], _timing, meta, _) do
    extra = Map.take(meta, ~w(channel payload)a)

    Sentry.capture_exception(meta.reason, stacktrace: meta.stacktrace, extra: extra)
  end

  def handle_event([:oban, :plugin, :exception], _timing, meta, _) do
    extra = Map.take(meta, ~w(plugin)a)

    Sentry.capture_exception(meta.reason, stacktrace: meta.stacktrace, extra: extra)
  end

  # NOTE: To be cleaned up once #3700 is released
  @analytics_queues ["analytics_imports", "google_analytics_imports"]

  defp on_job_exception(%Oban.Job{
         queue: queue,
         args: %{"site_id" => site_id, "source" => source},
         state: "executing",
         attempt: attempt,
         max_attempts: max_attempts
       })
       when queue in @analytics_queues and attempt >= max_attempts do
    site = Plausible.Repo.get(Plausible.Site, site_id)

    if site do
      Plausible.Workers.ImportAnalytics.import_failed(source, site)
    end
  end

  defp on_job_exception(%Oban.Job{
         queue: queue,
         args: %{"site_id" => site_id},
         state: "executing"
       })
       when queue in @analytics_queues do
    site = Plausible.Repo.get(Plausible.Site, site_id)
    Plausible.Purge.delete_imported_stats!(site)
  end

  defp on_job_exception(_job), do: :ignore
end
