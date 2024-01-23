defmodule Plausible.Imported.SiteImport do
  @moduledoc """
  Site import schema.
  """

  use Ecto.Schema

  @type t() :: %__MODULE__{}

  schema "site_imports" do
    field :start_date, :date
    field :end_date, :date
    field :source, :string
    field :status, :string

    belongs_to :site, Plausible.Site
    belongs_to :imported_by, Plausible.Auth.User

    timestamps()
  end
end
