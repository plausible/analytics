defmodule Plausible.Stats.CustomProps do
  @moduledoc """
  Module for querying user defined 'custom properties'.
  """

  alias Plausible.Stats.Filters
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base

  def fetch_prop_names(site, query) do
    case Filters.get_toplevel_filter(query, "event:props:") do
      [_op, "event:props:" <> key | _rest] ->
        [key]

      _ ->
        from(e in base_event_query(query),
          join: meta in fragment("meta"),
          hints: "ARRAY",
          on: true,
          select: meta.key,
          distinct: true
        )
        |> maybe_allowed_props_only(site)
        |> ClickhouseRepo.all()
    end
  end

  def maybe_allowed_props_only(q, site) do
    case Plausible.Props.allowed_for(site) do
      :all -> q
      allowed_props -> from [..., m] in q, where: m.key in ^allowed_props
    end
  end
end
