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
          site_default_threshold(site)

        "infinite" ->
          :infinite

        value_string ->
          {value, _} = Float.parse(value_string)
          value
      end

    Map.put(query, :sample_threshold, sample_threshold)
  end

  defp site_default_threshold(site) do
    if FunWithFlags.enabled?(:fractional_hardcoded_sample_rate, for: site) do
      # Hard-coded sample rate to temporarily fix an issue for a client.
      # To be solved as part of https://3.basecamp.com/5308029/buckets/39750953/messages/7978775089
      0.1
    else
      @default_sample_threshold
    end
  end
end
