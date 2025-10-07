defmodule Plausible.Stats.SamplingCache do
  @moduledoc """
  Cache storing estimation for events ingested by a team in the past month.

  Used for sampling rate calculations in Plausible.Stats.Sampling.
  """
  alias Plausible.Ingestion
  alias Plausible.Stats.Sampling

  import Ecto.Query
  use Plausible.Cache

  @cache_name :stats_sampling_cache

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_stats_sampling

  @impl true
  def repo(), do: Plausible.ClickhouseRepo

  @impl true
  def count_all() do
    base_db_query()
    |> repo().all()
    |> length()
  end

  @impl true
  def base_db_query() do
    from(r in Ingestion.Counters.Record,
      select: {
        r.site_id,
        selected_as(fragment("sumIf(value, metric = 'buffered')"), :events_ingested)
      },
      where: fragment("toDate(event_timebucket) >= ?", ^thirty_days_ago()),
      group_by: r.site_id
    )
  end

  @impl true
  def get_from_source(site_id) do
    base_db_query()
    |> repo().all()
    |> Map.new()
    |> Map.get(site_id)
  end

  @threshold Sampling.default_sample_threshold()

  def get(key, opts) do
    above_threshold_only? = Keyword.get(opts, :above_threshold_only?, true)

    case super(key, opts) do
      result when is_integer(result) and above_threshold_only? and result >= @threshold ->
        result

      # in case of consolidated gets we need to sum all values, in case only consolidated qualifies for threshold breach
      result when is_integer(result) and not above_threshold_only? ->
        result

      _ ->
        nil
    end
  end

  @spec consolidated_get(list(pos_integer()), Keyword.t()) :: pos_integer() | nil
  def consolidated_get(site_ids, opts \\ []) when is_list(site_ids) do
    opts = Keyword.put(opts, :above_threshold_only?, false)
    events_ingested = Enum.sum_by(site_ids, &(get(&1, opts) || 0))
    if events_ingested >= @threshold, do: events_ingested
  end

  defp thirty_days_ago() do
    Date.shift(Date.utc_today(), day: -30)
  end
end
