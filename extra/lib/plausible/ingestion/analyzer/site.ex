defmodule Plausible.Ingestion.Analyzer.Site do
  @moduledoc """
  Schema for  site request analyzer
  """

  use Ecto.Schema

  import Ecto.Changeset

  @valid_duration_seconds 3600
  @max_limit 10_000

  schema "analyzer_sites" do
    field :domain, :string
    field :limit, :integer
    field :valid_until, :naive_datetime

    timestamps()
  end

  def create_changeset(domain, limit, now) do
    valid_until = NaiveDateTime.shift(now, second: @valid_duration_seconds)

    %__MODULE__{}
    |> cast(%{limit: limit}, [:limit])
    |> put_change(:domain, domain)
    |> put_change(:valid_until, valid_until)
    |> validate_required(:limit)
    |> validate_number(:limit, greater_than: 1, less_than_or_equal_to: @max_limit)
  end
end
