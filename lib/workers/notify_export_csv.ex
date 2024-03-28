defmodule Plausible.Workers.NotifyExportCSV do
  @moduledoc "TODO"

  use Oban.Worker,
    queue: :csv_export_notify,
    max_attempts: 5

  alias PlausibleWeb.Router.Helpers, as: Routes

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{
      "storage" => storage,
      "site_id" => site_id
    } = args

    case storage do
      "s3" -> email_about_s3(args)
      "local" -> email_about_local(args)
    end

    # send out a notification to refresh exports in export/imports settings UI
    :ok = Plausible.Exports.oban_notify(site_id)
  end

  defp email_about_s3(args) do
    %{
      "email_to" => email_to,
      "s3_bucket" => s3_bucket,
      "s3_path" => s3_path
    } = args

    download_url = Plausible.S3.export_download_url(s3_bucket, s3_path)

    # NOTE: add settings url
    # NOTE: replace with proper Plausible.Email template
    Plausible.Mailer.deliver_now!(
      Bamboo.Email.new_email(
        from: PlausibleWeb.Email.mailer_email_from(),
        to: email_to,
        subject: "EXPORT SUCCESS",
        text_body: "download it from #{download_url}! hurry up, you have 24 hours!",
        html_body: """
        download it from <a href="#{download_url}">here!</a> hurry up, you have 24 hours!
        """
      )
    )
  end

  defp email_about_local(args) do
    %{
      "site_id" => site_id,
      "email_to" => email_to,
      "local_path" => local_path
    } = args

    domain = Plausible.Sites.get_domain!(site_id)

    download_url =
      Routes.site_url(
        PlausibleWeb.Endpoint,
        :download_local_export,
        domain,
        Path.basename(local_path)
      )

    settings_url =
      Routes.site_url(PlausibleWeb.Endpoint, :settings_imports_exports, domain)

    # NOTE: replace with proper Plausible.Email template
    Plausible.Mailer.deliver_now!(
      Bamboo.Email.new_email(
        from: PlausibleWeb.Email.mailer_email_from(),
        to: email_to,
        subject: "EXPORT SUCCESS",
        text_body: "download it from #{download_url} or manage it on #{settings_url}!",
        html_body: """
        download it from <a href="#{download_url}">here</a> or manage it <a href="#{settings_url}">in the settings!</a>
        """
      )
    )
  end
end
