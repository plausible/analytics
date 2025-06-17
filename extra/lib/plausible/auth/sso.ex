defmodule Plausible.Auth.SSO do
  @moduledoc """
  API for SSO.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Auth.SSO
  alias Plausible.Repo
  alias Plausible.Teams

  @type policy_attr() ::
          {:sso_default_role, Teams.Policy.sso_member_role()}
          | {:sso_session_timeout_minutes, non_neg_integer()}

  @spec get_integration_for(Teams.Team.t()) :: {:ok, SSO.Integration.t()} | {:error, :not_found}
  def get_integration_for(%Teams.Team{} = team) do
    query = integration_query() |> where([i], i.team_id == ^team.id)

    if integration = Repo.one(query) do
      {:ok, integration}
    else
      {:error, :not_found}
    end
  end

  @spec get_integration(String.t()) :: {:ok, SSO.Integration.t()} | {:error, :not_found}
  def get_integration(identifier) when is_binary(identifier) do
    query = integration_query() |> where([i], i.identifier == ^identifier)

    if integration = Repo.one(query) do
      {:ok, integration}
    else
      {:error, :not_found}
    end
  end

  defp integration_query() do
    from(i in SSO.Integration,
      inner_join: t in assoc(i, :team),
      as: :team,
      left_join: d in assoc(i, :sso_domains),
      as: :sso_domains,
      preload: [team: t, sso_domains: d]
    )
  end

  @spec initiate_saml_integration(Teams.Team.t()) :: SSO.Integration.t()
  def initiate_saml_integration(team) do
    changeset = SSO.Integration.init_changeset(team)

    Repo.insert!(changeset,
      on_conflict: [set: [updated_at: NaiveDateTime.utc_now(:second)]],
      conflict_target: :team_id,
      returning: true
    )
  end

  @spec update_integration(SSO.Integration.t(), map()) ::
          {:ok, SSO.Integration.t()} | {:error, Ecto.Changeset.t()}
  def update_integration(integration, params) do
    changeset = SSO.Integration.update_changeset(integration, params)

    case Repo.update(changeset) do
      {:ok, integration} -> {:ok, integration}
      {:error, changeset} -> {:error, changeset.changes.config}
    end
  end

  @spec provision_user(SSO.Identity.t()) ::
          {:ok, :standard | :sso | :integration, Teams.Team.t(), Auth.User.t()}
          | {:error, :integration_not_found | :over_limit}
          | {:error, :multiple_memberships, Teams.Team.t(), Auth.User.t()}
  def provision_user(identity) do
    case find_user(identity) do
      {:ok, :standard, user, integration, domain} ->
        provision_standard_user(user, identity, integration, domain)

      {:ok, :sso, user, integration, domain} ->
        provision_sso_user(user, identity, integration, domain)

      {:ok, :integration, _, integration, domain} ->
        provision_identity(identity, integration, domain)

      {:error, :not_found} ->
        {:error, :integration_not_found}
    end
  end

  @spec deprovision_user!(Auth.User.t()) :: Auth.User.t()
  def deprovision_user!(%{type: :standard} = user), do: user

  def deprovision_user!(user) do
    user = Repo.preload(user, [:sso_integration, :sso_domain])

    :ok = Auth.UserSessions.revoke_all(user)

    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:type, :standard)
    |> Ecto.Changeset.put_change(:sso_identity_id, nil)
    |> Ecto.Changeset.put_assoc(:sso_integration, nil)
    |> Ecto.Changeset.put_assoc(:sso_domain, nil)
    |> Repo.update!()
  end

  @spec update_policy(Teams.Team.t(), [policy_attr()]) ::
          {:ok, Teams.Team.t()} | {:error, Ecto.Changeset.t()}
  def update_policy(team, attrs \\ []) do
    params = Map.new(attrs)
    policy_changeset = Teams.Policy.update_changeset(team.policy, params)

    changeset =
      team
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:policy, policy_changeset)

    case Repo.update(changeset) do
      {:ok, integration} -> {:ok, integration}
      {:error, changeset} -> {:error, changeset.changes.policy}
    end
  end

  @spec set_force_sso(Teams.Team.t(), Teams.Policy.force_sso_mode()) ::
          {:ok, Teams.Team.t()}
          | {:error,
             :no_integration
             | :no_domain
             | :no_verified_domain
             | :owner_mfa_disabled
             | :no_sso_user}
  def set_force_sso(team, mode) do
    with :ok <- check_force_sso(team, mode) do
      policy_changeset = Teams.Policy.force_sso_changeset(team.policy, mode)

      team
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_embed(:policy, policy_changeset)
      |> Repo.update()
    end
  end

  @spec check_force_sso(Teams.Team.t(), Teams.Policy.force_sso_mode()) ::
          :ok
          | {:error,
             :no_integration
             | :no_domain
             | :no_verified_domain
             | :owner_mfa_disabled
             | :no_sso_user}
  def check_force_sso(_team, :none), do: :ok

  def check_force_sso(team, :all_but_owners) do
    with :ok <- check_integration_configured(team),
         :ok <- check_sso_user_present(team) do
      check_owners_mfa_enabled(team)
    end
  end

  @spec check_can_remove_integration(SSO.Integration.t()) ::
          :ok | {:error, :force_sso_enabled | :sso_users_present}
  def check_can_remove_integration(integration) do
    team = Repo.preload(integration, :team).team

    cond do
      team.policy.force_sso != :none ->
        {:error, :force_sso_enabled}

      check_sso_user_present(integration) == :ok ->
        {:error, :sso_users_present}

      true ->
        :ok
    end
  end

  @spec remove_integration(SSO.Integration.t(), Keyword.t()) ::
          :ok | {:error, :force_sso_enabled | :sso_users_present}
  def remove_integration(integration, opts \\ []) do
    force_deprovision? = Keyword.get(opts, :force_deprovision?, false)
    check = check_can_remove_integration(integration)

    case {check, force_deprovision?} do
      {:ok, _} ->
        Repo.delete!(integration)
        :ok

      {{:error, :sso_users_present}, true} ->
        users = Repo.preload(integration, :users).users

        {:ok, :ok} =
          Repo.transaction(fn ->
            Enum.each(users, &deprovision_user!/1)
            Repo.delete!(integration)
            :ok
          end)

        :ok

      {{:error, error}, _} ->
        {:error, error}
    end
  end

  defp check_integration_configured(team) do
    integrations =
      Repo.all(
        from(
          i in SSO.Integration,
          left_join: d in assoc(i, :sso_domains),
          where: i.team_id == ^team.id,
          preload: [sso_domains: d]
        )
      )

    domains = Enum.flat_map(integrations, & &1.sso_domains)
    no_verified_domains? = Enum.all?(domains, &(&1.status != :verified))

    cond do
      integrations == [] -> {:error, :no_integration}
      domains == [] -> {:error, :no_domain}
      no_verified_domains? -> {:error, :no_verified_domain}
      true -> :ok
    end
  end

  defp check_sso_user_present(%Teams.Team{} = team) do
    sso_user_count =
      Repo.aggregate(
        from(
          tm in Teams.Membership,
          inner_join: u in assoc(tm, :user),
          where: tm.team_id == ^team.id,
          where: tm.role != :guest,
          where: u.type == :sso
        ),
        :count
      )

    if sso_user_count > 0 do
      :ok
    else
      {:error, :no_sso_user}
    end
  end

  defp check_sso_user_present(%SSO.Integration{} = integration) do
    sso_user_count =
      Repo.aggregate(
        from(
          i in SSO.Integration,
          inner_join: u in assoc(i, :users),
          inner_join: tm in assoc(u, :team_memberships),
          on: tm.team_id == i.team_id,
          where: i.id == ^integration.id,
          where: tm.role != :guest,
          where: u.type == :sso
        ),
        :count
      )

    if sso_user_count > 0 do
      :ok
    else
      {:error, :no_sso_user}
    end
  end

  defp check_owners_mfa_enabled(team) do
    disabled_mfa_count =
      Repo.aggregate(
        from(
          tm in Teams.Membership,
          inner_join: u in assoc(tm, :user),
          where: tm.team_id == ^team.id,
          where: tm.role == :owner,
          where: u.totp_enabled == false or is_nil(u.totp_secret)
        ),
        :count
      )

    if disabled_mfa_count == 0 do
      :ok
    else
      {:error, :owner_mfa_disabled}
    end
  end

  defp find_user(identity) do
    case find_user_with_fallback(identity) do
      {:ok, type, user, integration, domain} ->
        {:ok, type, Repo.preload(user, [:sso_integration, :sso_domain]), integration, domain}

      {:error, _} = error ->
        error
    end
  end

  defp find_user_with_fallback(identity) do
    with {:error, :not_found} <- find_by_identity(identity) do
      find_by_email(identity.email)
    end
  end

  defp find_by_identity(identity) do
    if user = Repo.get_by(Auth.User, sso_identity_id: identity.id, type: :sso) do
      with {:ok, sso_domain} <- SSO.Domains.lookup(identity.email),
           :ok <- check_domain_integration_match(sso_domain, user) do
        user = Repo.preload(user, sso_integration: :team)

        {:ok, user.type, user, user.sso_integration, sso_domain}
      end
    else
      {:error, :not_found}
    end
  end

  defp find_by_email(email) do
    with {:ok, sso_domain} <- SSO.Domains.lookup(email) do
      case find_by_email(sso_domain.sso_integration.team, email) do
        {:ok, user} ->
          {:ok, user.type, user, sso_domain.sso_integration, sso_domain}

        {:error, :not_found} ->
          {:ok, :integration, nil, sso_domain.sso_integration, sso_domain}
      end
    end
  end

  defp find_by_email(team, email) do
    result =
      Repo.one(
        from(
          u in Auth.User,
          inner_join: tm in assoc(u, :team_memberships),
          where: u.email == ^email,
          where: tm.team_id == ^team.id,
          where: tm.role != :guest
        )
      )

    if result do
      {:ok, result}
    else
      {:error, :not_found}
    end
  end

  defp check_domain_integration_match(sso_domain, user) do
    if sso_domain.sso_integration_id == user.sso_integration_id do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp provision_sso_user(user, identity, integration, domain) do
    changeset =
      user
      |> change()
      |> put_change(:email, identity.email)
      |> put_change(:name, identity.name)
      |> put_change(:sso_identity_id, identity.id)
      |> put_change(:last_sso_login, NaiveDateTime.utc_now(:second))
      |> put_assoc(:sso_domain, domain)

    with {:ok, user} <- Repo.update(changeset) do
      {:ok, :sso, integration.team, user}
    end
  end

  defp provision_standard_user(user, identity, integration, domain) do
    changeset =
      user
      |> change()
      |> put_change(:type, :sso)
      |> put_change(:name, identity.name)
      |> put_change(:sso_identity_id, identity.id)
      |> put_change(:last_sso_login, NaiveDateTime.utc_now(:second))
      |> put_assoc(:sso_integration, integration)
      |> put_assoc(:sso_domain, domain)

    with :ok <- ensure_team_member(integration.team, user),
         :ok <- ensure_one_membership(user, integration.team),
         :ok <- Auth.UserSessions.revoke_all(user),
         {:ok, user} <- Repo.update(changeset) do
      {:ok, :standard, integration.team, user}
    end
  end

  defp provision_identity(identity, integration, domain) do
    random_password =
      64
      |> :crypto.strong_rand_bytes()
      |> Base.encode64(padding: false)

    params = %{
      email: identity.email,
      name: identity.name,
      password: random_password,
      password_confirmation: random_password
    }

    changeset =
      Auth.User.new(params)
      |> put_change(:email_verified, true)
      |> put_change(:type, :sso)
      |> put_change(:sso_identity_id, identity.id)
      |> put_change(:last_sso_login, NaiveDateTime.utc_now(:second))
      |> put_assoc(:sso_integration, integration)
      |> put_assoc(:sso_domain, domain)

    team = integration.team
    role = integration.team.policy.sso_default_role
    now = NaiveDateTime.utc_now(:second)

    result =
      Repo.transaction(fn ->
        with {:ok, user} <- Repo.insert(changeset),
             :ok <- Teams.Invitations.check_team_member_limit(team, role, user.email),
             {:ok, team_membership} <-
               Teams.Invitations.create_team_membership(team, role, user, now) do
          if team_membership.role != :guest do
            {:identity, team, user}
          else
            Repo.rollback(:integration_not_found)
          end
        else
          {:error, %{errors: [email: {_, attrs}]}} ->
            true = {:constraint, :unique} in attrs
            Repo.rollback(:integration_not_found)

          {:error, {:over_limit, _}} ->
            Repo.rollback(:over_limit)
        end
      end)

    case result do
      {:ok, {type, team, user}} ->
        {:ok, type, team, user}

      {:error, _} = error ->
        error
    end
  end

  defp ensure_team_member(team, user) do
    case Teams.Memberships.team_role(team, user) do
      {:ok, role} when role != :guest ->
        :ok

      _ ->
        {:error, :integration_not_found}
    end
  end

  defp ensure_one_membership(user, team) do
    query = Teams.Users.teams_query(user)

    if Repo.aggregate(query, :count) > 1 do
      {:error, :multiple_memberships, team, user}
    else
      :ok
    end
  end
end
