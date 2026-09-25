defmodule Plausible.Workers.LocalImportAnalyticsCleaner do
  @moduledoc """
  Worker for cleaning local files left after analytics import jobs.
  """

  use Oban.Worker, queue: :analytics_imports, unique: [period: 3600]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, attempt: attempt, max_attempts: max_attempts}) do
    %{"import_id" => import_id, "paths" => paths} = args

    if import_in_progress?(import_id) do
      {:snooze, _one_hour = 3600}
    else
      Enum.each(paths, &delete_path!(&1, import_id, attempt, max_attempts))
    end
  end

  defp delete_path!(path, import_id, attempt, max_attempts) do
    if File.exists?(path) do
      try do
        File.rm!(path)
      rescue
        e ->
          if attempt >= max_attempts do
            Logger.error(
              "Failed to delete leftover local import file #{path} for import_id=#{import_id}: #{Exception.message(e)}"
            )
          end

          reraise e, __STACKTRACE__
      end
    end
  end

  defp import_in_progress?(import_id) do
    import Ecto.Query
    require Plausible.Imported.SiteImport
    alias Plausible.Imported.SiteImport

    SiteImport
    |> where(id: ^import_id)
    |> where([i], i.status in ^[SiteImport.pending(), SiteImport.importing()])
    |> Plausible.Repo.exists?()
  end
end
