defmodule Plausible.Shield.IPRule do
  @moduledoc """
  Schema for IP block list
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "shield_rules_ip" do
    belongs_to :site, Plausible.Site
    field :inet, EctoNetwork.INET
    field :action, Ecto.Enum, values: [:deny, :allow], default: :deny
    field :description, :string
    field :added_by, :string

    # If `from_cache?` is set, the struct might be incomplete - see `Plausible.Site.Shield.Rules.IP.Cache`
    field :from_cache?, :boolean, virtual: true, default: false
    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:site_id, :inet, :description])
    |> validate_required([:site_id, :inet])
    |> disallow_netmask(:inet)
    |> unique_constraint(:inet,
      name: :shield_rules_ip_site_id_inet_index
    )
  end

  defp disallow_netmask(changeset, field) do
    case get_field(changeset, field) do
      %Postgrex.INET{netmask: netmask} when netmask != 32 and netmask != 128 ->
        add_error(changeset, field, "netmask unsupported")

      _ ->
        changeset
    end
  end
end
