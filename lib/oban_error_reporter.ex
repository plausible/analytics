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

  defp on_job_exception(%Oban.Job{
         queue: "analytics_imports",
         args: %{"import_id" => import_id},
         state: "executing",
         attempt: attempt,
         max_attempts: max_attempts
       })
       when attempt >= max_attempts do
    site_import = Plausible.Repo.get(Plausible.Imported.SiteImport, import_id)

    if site_import do
      Plausible.Workers.ImportAnalytics.import_fail(site_import)
    end
  end

  defp on_job_exception(%Oban.Job{
         queue: "analytics_imports",
         args: %{"import_id" => import_id},
         state: "executing"
       }) do
    site_import = Plausible.Repo.get(Plausible.Imported.SiteImport, import_id)

    if site_import do
      Plausible.Workers.ImportAnalytics.import_fail_transient(site_import)
    end
  end

  defp on_job_exception(_job), do: :ignore
end
