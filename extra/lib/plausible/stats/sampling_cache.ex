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
      group_by: r.site_id,
      having: selected_as(:events_ingested) > ^Sampling.default_sample_threshold()
    )
  end

  @impl true
  def get_from_source(site_id) do
    base_db_query()
    |> repo().all()
    |> Map.new()
    |> Map.get(site_id)
  end

  def thirty_days_ago() do
    Date.shift(Date.utc_today(), day: -30)
  end
end
