defmodule Plausible.Site.CustomDomain do
  use Ecto.Schema

  schema "custom_domains" do
    field :domain, :string
    field :has_ssl_certificate, :boolean
    belongs_to :site, Plausible.Site

    timestamps()
  end
end
