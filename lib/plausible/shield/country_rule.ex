defmodule Plausible.Shield.CountryRule do
  @moduledoc """
  Schema for Country Block List
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "shield_rules_country" do
    belongs_to :site, Plausible.Site
    field :country_code, :string
    field :action, Ecto.Enum, values: [:deny, :allow], default: :deny
    field :added_by, :string

    # If `from_cache?` is set, the struct might be incomplete - see `Plausible.Site.Shield.Rules.Country.Cache`
    field :from_cache?, :boolean, virtual: true, default: false
    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:site_id, :country_code, :added_by])
    |> validate_required([:site_id, :country_code])
    |> unique_constraint(:country_code,
      name: :shield_rules_country_site_id_country_code_index
    )
  end
end
