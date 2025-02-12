defmodule Plausible.Stats.GoalSuggestions do
  @moduledoc false

  alias Plausible.{Repo, ClickhouseRepo}
  alias Plausible.Stats.Query
  import Plausible.Stats.Base
  import Ecto.Query

  # As excluded goal names are interpolated as separate
  # parameters in the query, there's a risk of running
  # against max parameters limit. Given the failure mode
  # in this case is suggesting an event that is already
  # added as a goal, which will be validated when creating,
  # it's safe to trim exclusions list.
  @max_excluded 1000

  defmacrop visitors(e) do
    quote do
      selected_as(
        fragment("toUInt64(round(uniq(?)*any(_sample_factor)))", unquote(e).user_id),
        :visitors
      )
    end
  end

  def suggest_event_names(site, search_input, opts \\ []) do
    matches = "%#{search_input}%"

    site =
      site
      |> Repo.preload(:goals)

    excluded =
      opts
      |> Keyword.get(:exclude, [])
      |> Enum.take(@max_excluded)

    limit = Keyword.get(opts, :limit, 25)

    params = %{"with_imported" => "true", "period" => "6mo"}
    query = Query.from(site, params)

    native_q =
      from(e in base_event_query(site, query),
        where: fragment("? ilike ?", e.name, ^matches),
        where: e.name not in ["pageview", "engagement"],
        where: fragment("trim(?)", e.name) != "",
        where: e.name == fragment("trim(?)", e.name),
        where: e.name not in ^excluded,
        select: %{
          name: e.name,
          visitors: visitors(e)
        },
        order_by: selected_as(:visitors),
        group_by: e.name
      )
      |> maybe_set_limit(limit)

    date_range = Query.date_range(query)

    imported_q =
      from(i in "imported_custom_events",
        where: i.site_id == ^site.id,
        where: i.import_id in ^Plausible.Imported.complete_import_ids(site),
        where: i.date >= ^date_range.first and i.date <= ^date_range.last,
        where: i.visitors > 0,
        where: fragment("? ilike ?", i.name, ^matches),
        where: fragment("trim(?)", i.name) != "",
        where: i.name == fragment("trim(?)", i.name),
        where: i.name not in ^excluded,
        select: %{
          name: i.name,
          visitors: selected_as(sum(i.visitors), :visitors)
        },
        order_by: selected_as(:visitors),
        group_by: i.name
      )
      |> maybe_set_limit(limit)

    from(e in Ecto.Query.subquery(native_q),
      full_join: i in subquery(imported_q),
      on: e.name == i.name,
      select: selected_as(fragment("if(empty(?), ?, ?)", e.name, i.name, e.name), :name),
      order_by: [desc: e.visitors + i.visitors]
    )
    |> maybe_set_limit(limit)
    |> ClickhouseRepo.all()
    |> Enum.reject(&(String.length(&1) > Plausible.Goal.max_event_name_length()))
  end

  defp maybe_set_limit(q, :unlimited) do
    q
  end

  defp maybe_set_limit(q, limit) when is_integer(limit) and limit > 0 do
    limit(q, ^limit)
  end
end
