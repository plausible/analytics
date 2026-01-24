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

  @unknown_country_code "ZZ"

  @spec unknown_country_code() :: String.t()
  def unknown_country_code(), do: @unknown_country_code

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:site_id, :country_code])
    |> validate_required([:site_id, :country_code])
    |> validate_length(:country_code, is: 2)
    |> validate_change(:country_code, fn :country_code, cc ->
      valid_codes = [@unknown_country_code | Enum.map(Location.Country.all(), & &1.alpha_2)]

      if cc in valid_codes do
        []
      else
        [country_code: "is invalid"]
      end
    end)
    |> unique_constraint(:country_code,
      name: :shield_rules_country_site_id_country_code_index
    )
  end
end
