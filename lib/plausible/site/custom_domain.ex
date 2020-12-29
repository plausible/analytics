defmodule Plausible.Site.CustomDomain do
  use Ecto.Schema
  import Ecto.Changeset

  @domain_name_regex ~r/(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]/

  schema "custom_domains" do
    field :domain, :string
    field :has_ssl_certificate, :boolean
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(custom_domain, attrs) do
    custom_domain
    |> cast(attrs, [:domain, :site_id])
    |> validate_required([:domain, :site_id])
    |> validate_format(:domain, @domain_name_regex, message: "please enter a valid domain name")
  end
end
