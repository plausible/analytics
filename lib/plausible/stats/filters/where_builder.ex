defmodule Plausible.Stats.Filters.WhereBuilder do
  @moduledoc """
  A module for building a where clause of a query out of a query.
  """

  import Ecto.Query
  import Plausible.Stats.Base, only: [page_regex: 1]

  def add_filter(q, :events, [:is, "event:goal", {:page, path}]) do
    from(e in q, where: e.pathname == ^path and e.name == "pageview")
  end

  def add_filter(q, :events, [:matches, "event:goal", {:page, expr}]) do
    regex = page_regex(expr)

    from(e in q,
      where: fragment("match(?, ?)", e.pathname, ^regex) and e.name == "pageview"
    )
  end

  def add_filter(q, :events, [:is, "event:goal", {:event, event}]) do
    from(e in q, where: e.name == ^event)
  end

  def add_filter(q, :events, [:member, "event:goal", clauses]) do
    {events, pages} = split_goals(clauses)

    from(e in q,
      where: (e.pathname in ^pages and e.name == "pageview") or e.name in ^events
    )
  end

  def add_filter(q, :events, [:matches_member, "event:goal", clauses]) do
    {events, pages} = split_goals(clauses, &page_regex/1)

    event_clause =
      if Enum.any?(events) do
        dynamic([x], fragment("multiMatchAny(?, ?)", x.name, ^events))
      else
        dynamic([x], false)
      end

    page_clause =
      if Enum.any?(pages) do
        dynamic(
          [x],
          fragment("multiMatchAny(?, ?)", x.pathname, ^pages) and x.name == "pageview"
        )
      else
        dynamic([x], false)
      end

    where_clause = dynamic([], ^event_clause or ^page_clause)

    from(e in q, where: ^where_clause)
  end

  defp split_goals(clauses, map_fn \\ &Function.identity/1) do
    groups =
      Enum.group_by(clauses, fn {goal_type, _v} -> goal_type end, fn {_k, val} -> map_fn.(val) end)

    {
      Map.get(groups, :event, []),
      Map.get(groups, :page, [])
    }
  end
end
