defmodule Plausible.Workers.ImportGoogleAnalytics do
  use Plausible.Repo

  use Oban.Worker,
    queue: :google_analytics_imports,
    max_attempts: 3,
    unique: [fields: [:args], period: 60]

  @impl Oban.Worker
  def perform(
        %Oban.Job{
          args:
            %{
              "site_id" => site_id,
              "view_id" => view_id,
              "start_date" => start_date,
              "end_date" => end_date
            } = args
        },
        google_api \\ Plausible.Google.Api
      ) do
    site = Repo.get(Plausible.Site, site_id) |> Repo.preload([[memberships: :user]])
    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)
    date_range = Date.range(start_date, end_date)

    auth = {args["access_token"], args["refresh_token"], args["token_expires_at"]}

    case google_api.import_analytics(site, date_range, view_id, auth) do
      :ok ->
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
        import_failed(site)

        {:error, error}
    end
  end

  @impl Oban.Worker
  def backoff(_job) do
    # 5 minutes
    300
  end

  def import_failed(site) do
    site = Repo.preload(site, memberships: :user)

    Plausible.Site.import_failure(site) |> Repo.update!()
    Plausible.ClickhouseRepo.clear_imported_stats_for(site.id)

    Enum.each(site.memberships, fn membership ->
      if membership.role in [:owner, :admin] do
        PlausibleWeb.Email.import_failure(membership.user, site)
        |> Plausible.Mailer.send_email_safe()
      end
    end)
  end
end
