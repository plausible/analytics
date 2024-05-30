defmodule Plausible.Stats.Ecto.QueryBuilder do
  use Plausible

  import Ecto.Query

  alias Plausible.Stats.{Base, Query, TableDecider, Filters}
  alias Plausible.Stats.Ecto.Expression

  @no_ref "Direct / None"
  @not_set "(not set)"

  def build(site, query) do
    {event_metrics, sessions_metrics} = TableDecider.partition_metrics(query.metrics, query)

    build_events_query(site, query, event_metrics)
  end

  def build_events_query(site, query, event_metrics) do
    q =
      from(
        e in "events_v2",
        where: ^Filters.WhereBuilder.build(:events, site, query),
        select: ^Base.select_event_metrics(event_metrics)
      )

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, query)
    end

    q
    |> build_group_by(query)
    |> build_order_by(query)
  end

  defp build_group_by(q, %Query{dimensions: nil}), do: q

  defp build_group_by(q, query) do
    Enum.reduce(query.dimensions, q, fn dimension, q ->
      q
      |> select_merge(^%{dimension => Expression.dimension(dimension, query, :label)})
      |> group_by(^Expression.dimension(dimension, query, :group_by))
    end)
  end

  def build_order_by(q, query) do
    Enum.reduce(query.order_by, q, fn {metric_or_dimension, order_direction}, q ->
      order_by(
        q,
        [t],
        ^{order_direction, Expression.dimension(metric_or_dimension, query, :order_by)}
      )
    end)
  end
end

# alias Plausible.Stats.Query
# alias Plausible.Stats.Ecto.QueryBuilder

# site = Plausible.Repo.get_by(Plausible.Site, domain: "dummy.site")
# query = (Query.from(site, %{"period" => "all"})
#   |> Map.put(:dimensions, ["time:month", "event:props:amount"])
#   |> Map.put(:order_by, [{"time:month", :desc}])
#   |> Map.put(:timezone, site.timezone))

# query2 = (Query.from(site, %{"period" => "all"})
#   |> Map.put(:timezone, site.timezone))

# q = QueryBuilder.build_events_query(site, query, [:events, :pageviews])
# Plausible.ClickhouseRepo.all(q)

# q = QueryBuilder.build_events_query(site, query2, [:events, :pageviews])
