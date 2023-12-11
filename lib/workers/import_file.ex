defmodule Plausible.Workers.ImportFile do
  use Oban.Worker, queue: :local_imports, max_attempts: 3

  @impl true
  def perform(job) do
    %Oban.Job{args: %{"path" => path, "site_id" => site_id, "user_id" => user_id}} = job
    ensure_has_import_rights(user_id, site_id)

    if File.exists?(path) do
      Plausible.Import.import_file(path, site_id)
    else
      {:cancel, :enoent}
    end
  end

  defp ensure_has_import_rights(user_id, site_id) do
    :ok
  end
end
