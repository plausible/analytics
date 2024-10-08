defmodule ObanErrorReporter do
  use Plausible
  require Logger

  def handle_event(name, measurements, metadata, _) do
    # handling telemetry event in a try/catch block
    # to avoid handler detachment in the case of an error
    # see https://hexdocs.pm/telemetry/telemetry.html#attach/4
    try do
      handle_event(name, measurements, metadata)
    catch
      kind, reason ->
        message = Exception.format(kind, reason, __STACKTRACE__)
        Logger.error(message)
    end
  end

  defp handle_event([:oban, :job, :exception], measure, %{job: job} = meta) do
    extra =
      job
      |> Map.take([:id, :args, :meta, :queue, :worker])
      |> Map.merge(measure)

    on_job_exception(job)

    on_ce do
      log_ce_error(meta, extra)
    end

    Sentry.capture_exception(meta.reason, stacktrace: meta.stacktrace, extra: extra)
  end

  defp handle_event([:oban, :notifier, :exception], _timing, meta) do
    extra = Map.take(meta, ~w(channel payload)a)

    on_ce do
      log_ce_error(meta, extra)
    end

    Sentry.capture_exception(meta.reason, stacktrace: meta.stacktrace, extra: extra)
  end

  defp handle_event([:oban, :plugin, :exception], _timing, meta) do
    extra = Map.take(meta, ~w(plugin)a)

    on_ce do
      log_ce_error(meta, extra)
    end

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
      Plausible.Workers.ImportAnalytics.import_fail(site_import, [])
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

  on_ce do
    defp log_ce_error(meta, extra) do
      Logger.error(
        "Background job (#{inspect(extra)}) failed:\n\n  " <>
          Exception.format(:error, meta.reason, meta.stacktrace)
      )
    end
  end
end
