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
          {:ok, :standard | :sso | :integration, Auth.User.t()}
          | {:error, :integration_not_found}
          | {:error, :multiple_memberships, Teams.Team.t(), Auth.User.t()}
  def provision_user(identity) do
    case find_user(identity) do
      {:ok, :standard, user, integration} ->
        provision_standard_user(user, identity, integration)

      {:ok, :sso, user, _integration} ->
        provision_sso_user(user, identity)

      {:ok, :integration, integration} ->
        provision_identity(identity, integration)

      {:error, :not_found} ->
        {:error, :integration_not_found}
    end
  end

  defp find_user(identity) do
    case find_user_with_fallback(identity) do
      {:ok, type, user, integration} ->
        {:ok, type, Repo.preload(user, :sso_integration), integration}

      error ->
        error
    end
  end

  defp find_user_with_fallback(identity) do
    with {:error, :not_found} <- find_by_identity(identity.id) do
      find_by_email(identity.email)
    end
  end

  defp find_by_identity(id) do
    if user = Repo.get_by(Auth.User, sso_identity_id: id) do
      user = Repo.preload(user, :sso_integration)

      {:ok, user.type, user, user.sso_integration}
    else
      {:error, :not_found}
    end
  end

  defp find_by_email(email) do
    with {:ok, sso_domain} <- SSO.Domains.lookup(email) do
      case find_by_email(sso_domain.sso_integration.team, email) do
        {:ok, user} ->
          {:ok, user.type, user, sso_domain.sso_integration}

        {:error, :not_found} ->
          {:ok, :integration, sso_domain.sso_integration}
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

  defp provision_sso_user(user, identity) do
    changeset =
      user
      |> change()
      |> put_change(:email, identity.email)
      |> put_change(:name, identity.name)
      |> put_change(:sso_identity_id, identity.id)
      |> put_change(:last_sso_login, NaiveDateTime.utc_now(:second))

    with {:ok, user} <- Repo.update(changeset) do
      {:ok, :sso, user}
    end
  end

  defp provision_standard_user(user, identity, integration) do
    changeset =
      user
      |> change()
      |> put_change(:type, :sso)
      |> put_change(:name, identity.name)
      |> put_change(:sso_identity_id, identity.id)
      |> put_change(:last_sso_login, NaiveDateTime.utc_now(:second))
      |> put_assoc(:sso_integration, integration)

    with :ok <- ensure_team_member(integration.team, user),
         :ok <- ensure_one_membership(user, integration.team),
         {:ok, user} <- Repo.update(changeset) do
      {:ok, :standard, user}
    end
  end

  defp provision_identity(identity, integration) do
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

    case Repo.insert(changeset) do
      {:ok, user} ->
        {:ok, :identity, user}

      {:error, %{errors: [email: {_, attrs}]}} ->
        true = {:constraint, :unique} in attrs
        {:error, :integration_not_found}
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
