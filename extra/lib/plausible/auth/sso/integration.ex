defmodule Plausible.Auth.SSO.Integration do
  @moduledoc """
  Instance of particular SSO integration for a given team.

  Configuration is embedded and its type is dynamic, paving the
  way for potentially supporting other SSO mechanisms in the future,
  like OIDC.

  The UUID identifier can be used to uniquely identify the integration
  when configuring external services like IdPs.
  """

  use Plausible
  use Ecto.Schema

  import Ecto.Changeset
  import PolymorphicEmbed

  alias Plausible.Auth.SSO
  alias Plausible.Teams

  @type t() :: %__MODULE__{}

  on_ee do
    @derive {Plausible.Audit.Encoder, only: [:id, :identifier]}
  end

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
    has_many :sso_domains, SSO.Domain, foreign_key: :sso_integration_id

    timestamps()
  end

  @spec configured?(t()) :: boolean()
  def configured?(%__MODULE__{config: %config_mod{} = config}) do
    config_mod.configured?(config)
  end

  @spec init_changeset(Teams.Team.t()) :: Ecto.Changeset.t()
  def init_changeset(team) do
    params = %{config: %{__type__: :saml}}

    %__MODULE__{}
    |> cast(params, [])
    |> put_change(:identifier, Ecto.UUID.generate())
    |> cast_polymorphic_embed(:config)
    |> put_assoc(:team, team)
  end

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(integration, config_params) do
    params = tag_params(:saml, config_params)

    integration
    |> cast(params, [])
    |> cast_polymorphic_embed(:config,
      with: [
        saml: &SSO.SAMLConfig.update_changeset/2
      ]
    )
  end

  defp tag_params(type, params) when is_atom(type) and is_map(params) do
    case Enum.take(params, 1) do
      [{key, _}] when is_binary(key) ->
        %{"config" => Map.merge(%{"__type__" => Atom.to_string(type)}, params)}

      _ ->
        %{config: Map.merge(%{__type__: type}, params)}
    end
  end
end
