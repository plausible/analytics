defmodule Plausible.Auth.SSO.Domain do
  @moduledoc """
  Once SSO integration is initiated, it's possible to start
  allow-listing domains for it, in parallel with finalizing
  the setup on IdP's end.

  Each pending domain should be periodically checked for
  validity by testing for presence of TXT record, meta tag
  or URL. The moment whichever of them succeeds first, 
  the domain is marked as validated with method and timestamp 
  recorded.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "sso_domains" do
    field :identifier, Ecto.UUID
    field :domain, :string
    field :validated_via, Ecto.Enum, values: [:dns_txt, :url, :meta_tag]
    field :last_validated_at, :naive_datetime
    field :status, Ecto.Enum, values: [:pending, :validated], default: :pending

    belongs_to :sso_integration, Plausible.Auth.SSO.Integration

    timestamps()
  end

  def create_changeset(name) do
    %__MODULE__{}
    |> cast(%{name: name}, [:name])
    |> validate_required(:name)
  end
end
