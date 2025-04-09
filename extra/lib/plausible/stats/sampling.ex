defmodule Plausible.Stats.Sampling do
  @moduledoc """
  Sampling related functions
  """
  @default_sample_threshold 10_000_000
  # 1 percent
  @min_sample_rate 0.01

  import Ecto.Query

  alias Plausible.Stats.{Query, SamplingCache}

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

  @spec put_threshold(Plausible.Stats.Query.t(), Plausible.Site.t(), map()) ::
          Plausible.Stats.Query.t()
  def put_threshold(query, site, params) do
    sample_threshold =
      case params["sample_threshold"] do
        nil ->
          decide_sample_rate(site, query)

        "infinite" ->
          :no_sampling

        value_string ->
          {value, _} = Float.parse(value_string)
          value
      end

    Map.put(query, :sample_threshold, sample_threshold)
  end

  defp decide_sample_rate(site, query) do
    site.id
    |> SamplingCache.get()
    |> fractional_sample_rate(query)
  end

  def fractional_sample_rate(nil = _traffic_30_day, _query), do: :no_sampling

  def fractional_sample_rate(traffic_30_day, query) do
    date_range = Query.date_range(query)
    duration = Date.diff(date_range.last, date_range.first)
    estimated_traffic = traffic_30_day / 30.0 * duration

    fraction =
      if(estimated_traffic > 0,
        do: Float.round(@default_sample_threshold / estimated_traffic, 2),
        else: 1.0
      )

    cond do
      # Don't sample small time ranges
      duration < 1 -> :no_sampling
      # If sampling doesn't have a significant effect, don't sample
      fraction > 0.4 -> :no_sampling
      true -> max(fraction, @min_sample_rate)
    end
  end
end
