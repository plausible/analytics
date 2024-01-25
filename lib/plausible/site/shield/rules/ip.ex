defmodule Plausible.Site.Shield.Rules.IP do
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "shield_rules_ip" do
    belongs_to :site, Plausible.Site
    field :ip_address, EctoNetwork.INET
    field :action, Ecto.Enum, values: [:deny, :allow]
    field :description, :string
    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:site_id, :ip_address, :description])
    |> validate_required([:site_id, :ip_address])
    |> unique_constraint(:ip_address,
      name: :shield_rules_ip_site_id_ip_address_index
    )
  end
end
