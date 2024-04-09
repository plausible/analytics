defmodule Plausible.Workers.NotifyExportedAnalytics do
  @moduledoc "This worker delivers emails for successful and failed exports"

  use Oban.Worker,
    queue: :notify_exported_analytics,
    max_attempts: 5

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{
      "status" => status,
      "storage" => storage,
      "email_to" => email_to,
      "site_id" => site_id
    } = args

    user = Plausible.Repo.get_by!(Plausible.Auth.User, email: email_to)
    site = Plausible.Repo.get!(Plausible.Site, site_id)

    email =
      case status do
        "success" ->
          case storage do
            "s3" ->
              %{"s3_bucket" => s3_bucket, "s3_path" => s3_path} = args
              download_url = Plausible.S3.download_url(s3_bucket, s3_path)
              %{expires_at: expires_at} = Plausible.Exports.get_s3_export(site_id)
              PlausibleWeb.Email.export_success(user, site, download_url, expires_at)

            "local" ->
              download_url =
                PlausibleWeb.Router.Helpers.site_path(
                  PlausibleWeb.Endpoint,
                  :download_local_export,
                  site.domain
                )

              PlausibleWeb.Email.export_success(user, site, download_url, _expires_at = nil)
          end

        "failure" ->
          PlausibleWeb.Email.export_failure(user, site)
      end

    Plausible.Mailer.deliver_now!(email)
    :ok
  end
end
