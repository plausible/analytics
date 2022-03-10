defmodule Plausible.Workers.ImportGoogleAnalytics do
  use Plausible.Repo

  use Oban.Worker,
    queue: :google_analytics_imports,
    max_attempts: 1,
    unique: [fields: [:args], period: 60]

  @impl Oban.Worker
  def perform(
        %Oban.Job{args: %{"site_id" => site_id, "profile" => profile}},
        google_api \\ Plausible.Google.Api
      ) do
    site =
      Repo.get(Plausible.Site, site_id)
      |> Repo.preload([:google_auth, [memberships: :user]])

    case google_api.import_analytics(site, profile) do
      {:ok, _} ->
        Plausible.Site.import_success(site)
        |> Repo.update!()

        Enum.each(site.memberships, fn membership ->
          if membership.role in [:owner, :admin] do
            PlausibleWeb.Email.import_success(membership.user, site)
            |> Plausible.Mailer.send_email_safe()
          end
        end)

        :ok

      {:error, error} ->
        Plausible.Site.import_failure(site)
        |> Repo.update!()

        Enum.each(site.memberships, fn membership ->
          if membership.role in [:owner, :admin] do
            PlausibleWeb.Email.import_failure(membership.user, site)
            |> Plausible.Mailer.send_email_safe()
          end
        end)

        {:error, error}
    end
  end
end
