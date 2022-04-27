defmodule ErrorReporter do
  def handle_event([:oban, :job, :exception], measure, %{job: job} = meta, _) do
    extra =
      job
      |> Map.take([:id, :args, :meta, :queue, :worker])
      |> Map.merge(measure)

    on_job_exception(job)

    Sentry.capture_exception(meta.error, stacktrace: meta.stacktrace, extra: extra)
  end

  def handle_event([:oban, :circuit, :trip], _measure, meta, _) do
    Sentry.capture_exception(meta.error, stacktrace: meta.stacktrace, extra: meta)
  end

  defp on_job_exception(%Oban.Job{
         queue: "google_analytics_imports",
         args: %{"site_id" => site_id},
         state: "executing",
         attempt: attempt,
         max_attempts: max_attempts
       })
       when attempt >= max_attempts do
    site = Plausible.Repo.get(Plausible.Site, site_id)

    if site do
      Plausible.Workers.ImportGoogleAnalytics.import_failed(site)
    end
  end

  defp on_job_exception(%Oban.Job{
         queue: "google_analytics_imports",
         args: %{"site_id" => site_id},
         state: "executing"
       }) do
    Plausible.ClickhouseRepo.clear_imported_stats_for(site_id)
  end

  defp on_job_exception(_job), do: :ignore
end
