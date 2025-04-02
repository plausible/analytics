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

    site =
      Plausible.Site
      |> Plausible.Repo.get!(site_id)
      |> Plausible.Repo.preload(:team)

    email =
      case status do
        "success" ->
          case storage do
            "s3" ->
              %{expires_at: expires_at} = Plausible.Exports.get_s3_export!(site_id, _retries = 10)
              PlausibleWeb.Email.export_success(user, site, expires_at)

            "local" ->
              PlausibleWeb.Email.export_success(user, site, _expires_at = nil)
          end

        "failure" ->
          PlausibleWeb.Email.export_failure(user, site)
      end

    Plausible.Mailer.deliver_now!(email)
    :ok
  end
end
