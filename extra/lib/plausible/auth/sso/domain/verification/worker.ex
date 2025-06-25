defmodule Plausible.Auth.SSO.Domain.Verification.Worker do
  @moduledoc """
  Background service validating SSO domains ownership

  `bypass_checks` and `skip_checks` job args are for testing purposes only
  (former will fail the verification, latter will succeed with `dns_txt` method)
  """
  use Oban.Worker,
    queue: :sso_domain_ownership_verification,
    unique: true

  use Plausible.Auth.SSO.Domain.Status

  alias Plausible.Auth.SSO
  alias Plausible.Repo

  # roughly around 34h, given the snooze back-off
  @max_snoozes 14

  @spec cancel(String.t()) :: :ok
  def cancel(domain) do
    {:ok, job} =
      %{domain: domain}
      |> new()
      |> Oban.insert()

    Oban.cancel_job(job)
  end

  @spec enqueue(String.t()) :: {:ok, Oban.Job.t()}
  def enqueue(domain) do
    {:ok, job} =
      %{domain: domain}
      |> new()
      |> Oban.insert()

    :ok = Oban.retry_job(job)
    {:ok, job}
  end

  @impl true
  def perform(%{
        attempt: attempt,
        meta: meta,
        args: %{"domain" => domain}
      })
      when attempt <= @max_snoozes do
    service_opts = [
      skip_checks?: meta["skip_checks"] == true,
      verification_opts: [
        nameservers: Application.get_env(:plausible, :sso_verification_nameservers)
      ]
    ]

    service_opts =
      if meta["bypass_checks"] == true do
        Keyword.merge(service_opts, verification_opts: [methods: []])
      else
        service_opts
      end

    case SSO.Domains.get(domain) do
      {:ok, sso_domain} ->
        case SSO.Domains.verify(sso_domain, service_opts) do
          %SSO.Domain{status: Status.verified()} = verified ->
            verification_complete(sso_domain)
            {:ok, verified}

          _ ->
            {:snooze, snooze_backoff(attempt)}
        end

      {:error, :not_found} ->
        {:cancel, :domain_not_found}
    end
  end

  def perform(job) do
    verification_failure(job.args["domain"])
    {:cancel, :max_snoozes}
  end

  defp verification_complete(sso_domain) do
    send_success_notification(sso_domain)

    :ok
  end

  defp verification_failure(domain) do
    with {:ok, sso_domain} <- SSO.Domains.get(domain) do
      sso_domain
      |> SSO.Domains.mark_unverified!(Status.unverified())
      |> send_failure_notification()
    end

    :ok
  end

  defp send_success_notification(sso_domain) do
    owners = Repo.preload(sso_domain.sso_integration.team, :owners).owners

    Enum.each(owners, fn owner ->
      sso_domain.domain
      |> PlausibleWeb.Email.sso_domain_verification_success(owner)
      |> Plausible.Mailer.send()
    end)

    :ok
  end

  defp send_failure_notification(sso_domain) do
    owners = Repo.preload(sso_domain.sso_integration.team, :owners).owners

    Enum.each(owners, fn owner ->
      sso_domain.domain
      |> PlausibleWeb.Email.sso_domain_verification_failure(owner)
      |> Plausible.Mailer.send()
    end)

    :ok
  end

  defp snooze_backoff(attempt) do
    trunc(:math.pow(2, attempt - 1) * 15)
  end
end
