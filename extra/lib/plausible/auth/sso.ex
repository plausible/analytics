defmodule Plausible.Auth.SSO do
  @moduledoc """
  API for SSO.
  """

  alias Plausible.Auth.SSO
  alias Plausible.Repo
  alias Plausible.Teams

  @spec initiate_saml_integration(Teams.Team.t()) :: SSO.Integration.t()
  def initiate_saml_integration(team) do
    changeset = SSO.Integration.init_changeset(team)

    Repo.insert!(changeset,
      on_conflict: [set: [updated_at: NaiveDateTime.utc_now()]],
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
end
