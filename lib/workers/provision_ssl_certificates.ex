defmodule Plausible.Workers.ProvisionSslCertificates do
  use Plausible.Repo
  use Oban.Worker, queue: :provision_ssl_certificates, max_attempts: 1
  require Logger
  @timeout 20_000

  @impl Oban.Worker
  def perform(_job, ssh \\ SSHEx) do
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
      res =
        ssh.run(
          conn,
          'sudo certbot certonly --webroot -w /root/webroot -n -d \"#{domain.domain}\"',
          channel_timeout: @timeout,
          exec_timeout: @timeout
        )

      case res do
        {:ok, msg, code} ->
          report_result({msg, code}, domain)

        e ->
          Logger.warn("Error obtaining SSL certificate for #{domain.domain}: #{inspect(e)}")
      end
    end

    :ok
  end

  defp report_result({_, 0}, domain) do
    Ecto.Changeset.change(domain, has_ssl_certificate: true) |> Repo.update!()
    Plausible.Slack.notify("Obtained SSL cert for #{domain.domain}")
    :ok
  end

  defp report_result({error_msg, error_code}, domain) do
    Logger.warn(
      "Error obtaining SSL certificate for #{domain.domain}: #{error_msg} (code=#{error_code})"
    )

    # Failing to obtain is expected, not a failure for the job queue
    :ok
  end

  defp get_config() do
    Application.get_env(:plausible, :custom_domain_server)
  end
end
