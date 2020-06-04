defmodule Plausible.Workers.ProvisionSslCertificates do
  use Plausible.Repo
  use Oban.Worker, queue: :provision_ssl_certificates
	@custom_domain_server Application.get_env(:plausible, :custom_domain_server)

  @impl Oban.Worker
  def perform(_args, _job, ssh \\ SSHEx) do
    IO.inspect(@custom_domain_server)
    {:ok, conn} = ssh.connect(
      ip: to_charlist(@custom_domain_server[:ip]),
      user: to_charlist(@custom_domain_server[:user]),
      user_dir: '/app/.ssh'
    )

    recent_custom_domains = Repo.all(
      from cd in Plausible.Site.CustomDomain,
      where: cd.updated_at > fragment("now() - '3 days'::interval"),
      where: not cd.has_ssl_certificate
    )

    for domain <- recent_custom_domains do
      {:ok, res, code} = ssh.run(conn, 'sudo certbot certonly --nginx -n -d \"#{domain.domain}\"')
      report_result({res, code}, domain)
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
