defmodule Plausible.Workers.ImportGoogleAnalytics do
  use Plausible.Repo

  use Oban.Worker,
    queue: :google_analytics_imports,
    max_attempts: 1,
    unique: [fields: [:args], period: 60]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"site_id" => site_id, "profile" => profile}}) do
    site =
      Repo.get(Plausible.Site, site_id)
      |> Repo.preload(:google_auth)

    case Plausible.Google.Api.import_analytics(site, profile) do
      {:ok, _} ->
        site
        |> Plausible.Site.set_imported_source("Google Analytics")
        |> Repo.update!()

        # TODO: Send email to update user
        :ok

      {:error, error} ->
        # TODO: Send failure email
        {:error, error}
    end
  end
end
