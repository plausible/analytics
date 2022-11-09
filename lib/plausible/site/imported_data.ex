defmodule Plausible.Site.ImportedData do
  @moduledoc """
  Embedded schema for Google Analytics imports
  """
  use Ecto.Schema

  embedded_schema do
    field :start_date, :date
    field :end_date, :date
    field :source, :string
    field :status, :string
  end
end
