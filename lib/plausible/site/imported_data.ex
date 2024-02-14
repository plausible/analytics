defmodule Plausible.Site.ImportedData do
  @moduledoc """
  Embedded schema for analytics imports
  """
  use Ecto.Schema

  @type t() :: %__MODULE__{}

  embedded_schema do
    field :start_date, :date
    field :end_date, :date
    field :source, :string
    field :status, :string
  end
end
