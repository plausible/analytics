defmodule Plausible.Stats.Base do
  use Plausible

  alias Plausible.Stats.{TableDecider, SQL}
  import Ecto.Query

  def base_event_query(site, query) do
    events_q = query_events(site, query)

    if TableDecider.events_join_sessions?(query) do
      sessions_q =
        from(
          s in query_sessions(site, query),
          select: %{session_id: s.session_id},
          where: s.sign == 1,
          group_by: s.session_id
        )

      from(
        e in events_q,
        join: sq in subquery(sessions_q),
        on: e.session_id == sq.session_id
      )
    else
      events_q
    end
  end

  defp query_events(_site, query) do
    q = from(e in "events_v2", where: ^SQL.WhereBuilder.build(:events, query))

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, query)
    end

    q
  end

  def query_sessions(_site, query) do
    q = from(s in "sessions_v2", where: ^SQL.WhereBuilder.build(:sessions, query))

    on_ee do
      q = Plausible.Stats.Sampling.add_query_hint(q, query)
    end

    q
  end
end
