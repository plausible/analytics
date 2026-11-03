defmodule Plausible.Workers.LocalImportAnalyticsCleaner do
  @moduledoc """
  Worker for cleaning local files left after analytics import jobs.
  """

  use Oban.Worker, queue: :analytics_imports, unique: [period: 3600]

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{"import_id" => import_id, "paths" => paths} = args

    if import_in_progress?(import_id) do
      {:snooze, _one_hour = 3600}
    else
      Enum.each(paths, fn path ->
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        if File.exists?(path), do: File.rm!(path)
      end)
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
