defmodule Plausible.Workers.ProvisionSslCertificates do
  use Plausible.Repo
  use Oban.Worker, queue: :provision_ssl_certificates

  @impl Oban.Worker
  def perform(_args, _job, system \\ System) do
    recent_custom_domains = Repo.all(
      from cd in Plausible.Site.CustomDomain,
      where: cd.updated_at > fragment("now() - '3 days'::interval"),
      where: not cd.has_ssl_certificate
    )

    for domain <- recent_custom_domains do
      system.cmd("ssh", ["-t", "ubuntu@custom.plausible.io", "sudo certbot certonly --nginx -n -d #{domain.domain}"])
      |> report_result(domain)
    end
  end

  defp report_result({_, 0}, domain) do
    Ecto.Changeset.change(domain, has_ssl_certificate: true) |> Repo.update!
    Plausible.Slack.notify("Obtained SSL cert for #{domain.domain}")
    :ok
  end

  defp report_result({error_msg, error_code}, domain) do
    Sentry.capture_message("Error obtaining SSL certificate", extra: %{error_msg: error_msg, error_code: error_code, domain: domain.domain})
    :ok # Failing to obtain is expected, not a failure for the job queue
  end
end
