defmodule Plausible.Auth.SSO.SAMLConfig do
  @moduledoc """
  SAML SSO can be configured in two ways - by either providing IdP
  metadata XML or inputting required data one by one.

  If metadata is provided, the parameters are extracted but the
  original metadata is preserved as well. This might be helpful
  when updating configuration in the future to enable some other
  feature like Single Logout without having to re-fetch metadata
  from IdP again.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @fields [:idp_signin_url, :idp_entity_id, :idp_cert_pem, :idp_metadata]

  embedded_schema do
    field :idp_signin_url, :string
    field :idp_entity_id, :string
    field :idp_cert_pem, :string
    field :idp_metadata, :string
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
  end
end
