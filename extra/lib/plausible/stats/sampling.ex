defmodule Plausible.Stats.Sampling do
  @moduledoc """
  Sampling related functions
  """
  @default_sample_threshold 20_000_000

  import Ecto.Query

  @spec add_query_hint(Ecto.Query.t(), Plausible.Stats.Query.t()) :: Ecto.Query.t()
  def add_query_hint(%Ecto.Query{} = db_query, %Plausible.Stats.Query{} = query) do
    case query.sample_threshold do
      :infinite ->
        db_query

      threshold ->
        add_query_hint(db_query, threshold)
    end
  end

  @spec add_query_hint(Ecto.Query.t(), pos_integer()) :: Ecto.Query.t()
  def add_query_hint(%Ecto.Query{} = query, threshold) when is_integer(threshold) do
    from(x in query, hints: unsafe_fragment(^"SAMPLE #{threshold}"))
  end

  @spec add_query_hint(Ecto.Query.t()) :: Ecto.Query.t()
  def add_query_hint(%Ecto.Query{} = query) do
    add_query_hint(query, @default_sample_threshold)
  end

  @spec put_threshold(Plausible.Stats.Query.t(), map()) :: Plausible.Stats.Query.t()
  def put_threshold(query, params) do
    sample_threshold =
      case params["sample_threshold"] do
        nil -> @default_sample_threshold
        "infinite" -> :infinite
        value -> String.to_integer(value)
      end

    Map.put(query, :sample_threshold, sample_threshold)
  end
end
