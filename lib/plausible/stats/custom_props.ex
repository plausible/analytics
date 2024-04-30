defmodule Plausible.Stats.CustomProps do
  @moduledoc """
  Module for querying user defined 'custom properties'.
  """

  alias Plausible.Stats.Query
  use Plausible.ClickhouseRepo
  import Plausible.Stats.Base

  def fetch_prop_names(site, query) do
    case Query.get_filter_by_prefix(query, "event:props:") do
      {"event:props:" <> key, _} ->
        [key]

      _ ->
        from(e in base_event_query(site, query),
          array_join: meta in fragment("meta"),
          select: meta.key,
          distinct: true
        )
        |> maybe_allowed_props_only(site)
        |> ClickhouseRepo.all(label: :fetch_prop_names)
    end
  end

  def maybe_allowed_props_only(q, site) do
    case Plausible.Props.allowed_for(site) do
      :all -> q
      allowed_props -> from [..., m] in q, where: m.key in ^allowed_props
    end
  end
end
