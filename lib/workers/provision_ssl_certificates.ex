defmodule Plausible.Workers.ProvisionSslCertificates do
  use Plausible.Repo
  use Oban.Worker, queue: :provision_ssl_certificates, max_attempts: 1
  require Logger

  @impl Oban.Worker
  def perform(_args, _job, ssh \\ SSHEx) do
    config = get_config()

    {:ok, conn} =
      ssh.connect(
        ip: to_charlist(config[:ip]),
        user: to_charlist(config[:user]),
        password: to_charlist(config[:password])
      )

    recent_custom_domains =
      Repo.all(
        from cd in Plausible.Site.CustomDomain,
          where: cd.updated_at > fragment("now() - '3 days'::interval"),
          where: not cd.has_ssl_certificate
      )

    for domain <- recent_custom_domains do
      {:ok, res, code} = ssh.run(conn, 'sudo certbot certonly --nginx -n -d \"#{domain.domain}\"')
      report_result({res, code}, domain)
    end

    :ok
  end

  defp report_result({_, 0}, domain) do
    Ecto.Changeset.change(domain, has_ssl_certificate: true) |> Repo.update!()
    Plausible.Slack.notify("Obtained SSL cert for #{domain.domain}")
    :ok
  end

  defp report_result({error_msg, error_code}, domain) do
    Logger.error(
      "Error obtaining SSL certificate for #{domain.domain}: #{error_msg} (code=#{error_code})"
    )

    # Failing to obtain is expected, not a failure for the job queue
    :ok
  end

  defp get_config() do
    Application.get_env(:plausible, :custom_domain_server)
  end
end
