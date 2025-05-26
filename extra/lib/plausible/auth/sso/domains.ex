defmodule Plausible.Auth.SSO.Domains do
  @moduledoc """
  API for SSO domains.
  """

  import Ecto.Query

  alias Plausible.Auth.SSO
  alias Plausible.Repo

  @spec add(SSO.Integration.t(), String.t()) ::
          {:ok, SSO.Domain.t()} | {:error, Ecto.Changeset.t()}
  def add(integration, domain) do
    changeset = SSO.Domain.create_changeset(integration, domain)

    Repo.insert(changeset)
  end

  @spec verify(SSO.Domain.t(), Keyword.t()) :: SSO.Domain.t()
  def verify(sso_domain, opts \\ []) do
    skip_checks? = Keyword.get(opts, :skip_checks?, false)
    now = Keyword.get(opts, :now, NaiveDateTime.utc_now(:second))

    if skip_checks? do
      mark_valid(sso_domain, :dns_txt, now)
    else
      mark_invalid(sso_domain, now)
    end
  end

  @spec lookup(String.t()) :: {:ok, SSO.Domain.t()} | {:error, :not_found}
  def lookup(domain_or_email) when is_binary(domain_or_email) do
    search = normalize_lookup(domain_or_email)

    result =
      from(
        d in SSO.Domain,
        inner_join: i in assoc(d, :sso_integration),
        inner_join: t in assoc(i, :team),
        where: d.domain == ^search,
        where: d.status == :validated,
        preload: [sso_integration: {i, team: t}]
      )
      |> Repo.one()

    if result do
      {:ok, result}
    else
      {:error, :not_found}
    end
  end

  defp normalize_lookup(domain_or_email) do
    domain_or_email
    |> String.split("@", parts: 2)
    |> List.last()
    |> String.trim()
    |> String.downcase()
  end

  defp mark_valid(sso_domain, method, now) do
    sso_domain
    |> SSO.Domain.valid_changeset(method, now)
    |> Repo.update!()
  end

  defp mark_invalid(sso_domain, now) do
    sso_domain
    |> SSO.Domain.invalid_changeset(now)
    |> Repo.update!()
  end
end
