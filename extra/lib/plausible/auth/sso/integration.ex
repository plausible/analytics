defmodule Plausible.Auth.SSO.Integration do
  @moduledoc """
  Instance of particular SSO integration for a given team.

  Configuration is embedded and its type is dynamic, paving the
  way for potentially supporting other SSO mechanisms in the future,
  like OIDC.

  The UUID identifier can be used to uniquely identify the integration
  when configuring external services like IdPs.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import PolymorphicEmbed

  alias Plausible.Auth.SSO

  @type t() :: %__MODULE__{}

  schema "sso_integrations" do
    field :identifier, Ecto.UUID

    polymorphic_embeds_one :config,
      types: [
        saml: SSO.SAMLConfig
      ],
      on_type_not_found: :raise,
      on_replace: :update

    belongs_to :team, Plausible.Teams.Team
    has_many :users, Plausible.Auth.User, foreign_key: :sso_integration_id

    timestamps()
  end

  def init_changeset(team) do
    params = %{config: %{__type__: :saml}}

    %__MODULE__{}
    |> cast(params, [])
    |> put_change(:identifier, Ecto.UUID.generate())
    |> cast_polymorphic_embed(:config)
    |> put_assoc(:team, team)
  end

  def update_changeset(integration, config_params) do
    params = %{config: Map.merge(%{__type__: :saml}, config_params)}

    integration
    |> cast(params, [])
    |> cast_polymorphic_embed(:config)
  end
end
