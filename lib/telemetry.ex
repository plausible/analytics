defmodule ErrorReporter do
  def handle_event([:oban, :job, :exception], measure, %{job: job} = meta, _) do
    extra =
      job
      |> Map.take([:id, :args, :meta, :queue, :worker])
      |> Map.merge(measure)

    maybe_log_import_error(job)

    Sentry.capture_exception(meta.error, stacktrace: meta.stacktrace, extra: extra)
  end

  def handle_event([:oban, :circuit, :trip], _measure, meta, _) do
    Sentry.capture_exception(meta.error, stacktrace: meta.stacktrace, extra: meta)
  end

  defp maybe_log_import_error(job) do
    site = Plausible.Repo.get(Plausible.Site, job.args["site_id"])

    if site do
      Plausible.Site.import_failure(site) |> Plausible.Repo.update!()
    end
  end
end
