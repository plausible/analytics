defmodule Plausible.Auth.SSO.Domain.Validation.Worker do
  @moduledoc """
  Background service validating SSO domains ownership

  `bypass_checks` and `skip_checks` job args are for testing purposes only
  (former will fail the verification, latter will succeed with `dns_txt` method)
  """
  use Oban.Worker,
    queue: :sso_domain_validations,
    unique: true

  alias Plausible.Auth.SSO
  alias Plausible.Repo

  # roughly around 34h, given the snooze back-off
  @max_snoozes 14

  def enqueue(domain) do
    {:ok, result} =
      Repo.transaction(fn ->
        with {:ok, sso_domain} <- SSO.Domains.get(domain) do
          SSO.Domains.mark_invalid!(sso_domain, :in_progress)
        end

        {:ok, job} =
          %{domain: domain}
          |> new()
          |> Oban.insert()

        :ok = Oban.retry_job(job)
        {:ok, job}
      end)

    result
  end

  @impl true
  def perform(%{
        attempt: attempt,
        meta: meta,
        args: %{"domain" => domain}
      })
      when attempt <= @max_snoozes do
    service_opts = [
      skip_checks?: meta["skip_checks"] == true
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
          %SSO.Domain{status: :validated} = validated ->
            validation_complete(sso_domain)
            {:ok, validated}

          _ ->
            {:snooze, snooze_backoff(attempt)}
        end

      {:error, :not_found} ->
        {:cancel, :domain_not_found}
    end
  end

  def perform(job) do
    validation_failure(job.args["domain"])
    {:cancel, :max_snoozes}
  end

  defp validation_complete(sso_domain) do
    send_success_notification(sso_domain)

    :ok
  end

  defp validation_failure(domain) do
    with {:ok, sso_domain} <- SSO.Domains.get(domain) do
      sso_domain
      |> SSO.Domains.mark_invalid!(:invalid)
      |> send_failure_notification()
    end

    :ok
  end

  defp send_success_notification(sso_domain) do
    owners = Repo.preload(sso_domain.sso_integration.team, :owners).owners

    Enum.each(owners, fn owner ->
      sso_domain.domain
      |> PlausibleWeb.Email.sso_domain_validation_success(owner)
      |> Plausible.Mailer.send()
    end)

    :ok
  end

  defp send_failure_notification(sso_domain) do
    owners = Repo.preload(sso_domain.sso_integration.team, :owners).owners

    Enum.each(owners, fn owner ->
      sso_domain.domain
      |> PlausibleWeb.Email.sso_domain_validation_failure(owner)
      |> Plausible.Mailer.send()
    end)

    :ok
  end

  defp snooze_backoff(attempt) do
    trunc(:math.pow(2, attempt - 1) * 15)
  end
end
