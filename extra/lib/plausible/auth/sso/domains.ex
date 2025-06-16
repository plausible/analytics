defmodule Plausible.Auth.SSO.Domains do
  @moduledoc """
  API for SSO domains.
  """

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Auth.SSO
  alias Plausible.Repo

  @spec add(SSO.Integration.t(), String.t()) ::
          {:ok, SSO.Domain.t()} | {:error, Ecto.Changeset.t()}
  def add(integration, domain) do
    changeset = SSO.Domain.create_changeset(integration, domain)

    Repo.insert(changeset)
  end

  @spec verify(SSO.Domain.t(), Keyword.t()) :: SSO.Domain.t()
  def verify(%SSO.Domain{} = sso_domain, opts \\ []) do
    skip_checks? = Keyword.get(opts, :skip_checks?, false)
    verification_opts = Keyword.get(opts, :verification_opts, [])
    now = Keyword.get(opts, :now, NaiveDateTime.utc_now(:second))

    if skip_checks? do
      mark_validated!(sso_domain, :dns_txt, now)
    else
      case SSO.Domain.Validation.run(sso_domain.domain, sso_domain.identifier, verification_opts) do
        {:ok, step} ->
          mark_validated!(sso_domain, step, now)

        {:error, :invalid} ->
          mark_invalid!(sso_domain, :in_progress, now)
      end
    end
  end

  @spec get(String.t()) :: {:ok, SSO.Domain.t()} | {:error, :not_found}
  def get(domain) when is_binary(domain) do
    result =
      from(
        d in SSO.Domain,
        inner_join: i in assoc(d, :sso_integration),
        inner_join: t in assoc(i, :team),
        where: d.domain == ^domain,
        preload: [sso_integration: {i, team: t}]
      )
      |> Repo.one()

    if result do
      {:ok, result}
    else
      {:error, :not_found}
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

  @spec remove(SSO.Domain.t(), Keyword.t()) ::
          :ok | {:error, :force_sso_enabled | :sso_users_present}
  def remove(sso_domain, opts \\ []) do
    force_deprovision? = Keyword.get(opts, :force_deprovision?, false)

    check = check_can_remove(sso_domain)

    case {check, force_deprovision?} do
      {:ok, _} ->
        Repo.delete!(sso_domain)
        :ok

      {{:error, :sso_users_present}, true} ->
        domain_users = users_by_domain(sso_domain)

        {:ok, :ok} =
          Repo.transaction(fn ->
            Enum.each(domain_users, &SSO.deprovision_user!/1)
            Repo.delete!(sso_domain)
            :ok
          end)

        :ok

      {{:error, error}, _} ->
        {:error, error}
    end
  end

  @spec check_can_remove(SSO.Domain.t()) ::
          :ok | {:error, :force_sso_enabled | :sso_users_present}
  def check_can_remove(sso_domain) do
    sso_domain = Repo.preload(sso_domain, sso_integration: [:team, :sso_domains])
    team = sso_domain.sso_integration.team
    domain_users_count = sso_domain |> users_by_domain_query() |> Repo.aggregate(:count)

    integration_users_count =
      sso_domain.sso_integration |> users_by_integration_query() |> Repo.aggregate(:count)

    only_domain_with_users? =
      domain_users_count > 0 and integration_users_count == domain_users_count

    cond do
      team.policy.force_sso != :none and only_domain_with_users? ->
        {:error, :force_sso_enabled}

      domain_users_count > 0 ->
        {:error, :sso_users_present}

      true ->
        :ok
    end
  end

  @spec mark_validated!(SSO.Domain.t(), SSO.Domain.validation_method(), DateTime.t()) ::
          SSO.Domain.t()
  def mark_validated!(sso_domain, method, now \\ NaiveDateTime.utc_now(:second)) do
    sso_domain
    |> SSO.Domain.valid_changeset(method, now)
    |> Repo.update!()
  end

  @spec mark_invalid!(SSO.Domain.t(), atom(), DateTime.t()) :: SSO.Domain.t()
  def mark_invalid!(sso_domain, status, now \\ NaiveDateTime.utc_now(:second)) do
    sso_domain
    |> SSO.Domain.invalid_changeset(now, status)
    |> Repo.update!()
  end

  defp users_by_domain(sso_domain) do
    sso_domain
    |> users_by_domain_query()
    |> Repo.all()
  end

  defp users_by_domain_query(sso_domain) do
    from(
      u in Auth.User,
      where: u.sso_domain_id == ^sso_domain.id
    )
  end

  defp users_by_integration_query(sso_integration) do
    from(
      u in Auth.User,
      where: u.sso_integration_id == ^sso_integration.id,
      where: u.type == :sso
    )
  end

  defp normalize_lookup(domain_or_email) do
    domain_or_email
    |> String.split("@", parts: 2)
    |> List.last()
    |> String.trim()
    |> String.downcase()
  end
end
