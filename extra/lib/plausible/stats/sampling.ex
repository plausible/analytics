defmodule Plausible.Stats.Sampling do
  @moduledoc """
  Sampling related functions
  """
  @default_sample_threshold 10_000_000
  @max_sample_threshold 100_000_000

  import Ecto.Query

  alias Plausible.Stats.Query

  def default_sample_threshold(), do: @default_sample_threshold

  @spec add_query_hint(Ecto.Query.t(), Plausible.Stats.Query.t()) :: Ecto.Query.t()
  def add_query_hint(%Ecto.Query{} = db_query, %Plausible.Stats.Query{} = query) do
    case query.sample_threshold do
      :no_sampling ->
        db_query

      nil ->
        db_query

      threshold ->
        add_query_hint(db_query, threshold)
    end
  end

  @spec add_query_hint(Ecto.Query.t(), pos_integer() | float()) :: Ecto.Query.t()
  def add_query_hint(%Ecto.Query{} = query, threshold) when is_number(threshold) do
    from(x in query, hints: unsafe_fragment(^"SAMPLE #{threshold}"))
  end

  @spec add_query_hint(Ecto.Query.t()) :: Ecto.Query.t()
  def add_query_hint(%Ecto.Query{} = query) do
    add_query_hint(query, @default_sample_threshold)
  end

  @spec put_threshold(Plausible.Stats.Query.t(), map()) ::
          Plausible.Stats.Query.t()
  def put_threshold(query, params) do
    sample_threshold =
      case params["sample_threshold"] do
        nil ->
          fractional_sample_rate(query)

        "infinite" ->
          :no_sampling

        value_string ->
          {value, _} = Integer.parse(value_string)
          value
      end

    Map.put(query, :sample_threshold, sample_threshold)
  end

  def fractional_sample_rate(_query),
    do: :no_sampling

  def fractional_sample_rate(query) do
    date_range = Query.date_range(query)
    duration = Date.diff(date_range.last, date_range.first)

    if duration >= 1 do
      min(@max_sample_threshold, adjust_sample_threshold(query.filters))
    else
      :no_sampling
    end
  end

  @filter_traffic_multiplier 5.0
  @max_filters 2

  defp adjust_sample_threshold(filters) do
    @default_sample_threshold * @filter_traffic_multiplier ** min(length(filters), @max_filters)
  end
end
