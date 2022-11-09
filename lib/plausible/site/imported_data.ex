defmodule Plausible.Site.ImportedData do
  use Ecto.Schema

  embedded_schema do
    field :start_date, :date
    field :end_date, :date
    field :source, :string
    field :status, :string
  end
end
