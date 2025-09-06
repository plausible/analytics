defmodule Plausible.Ingestion.Analyzer.Log do
  @moduledoc """
  Schema for  site request analyzer
  """

  use Ecto.Schema

  schema "analyzer_logs" do
    field :domain, :string
    field :request, :map
    field :headers, :map
    field :drop_reason, :string

    timestamps(updated_at: false, type: :naive_datetime_usec)
  end
end
