defmodule Plausible.Stats.GoalSuggestions do
  alias Plausible.{Repo, ClickhouseRepo}
  alias Plausible.Stats.Query
  import Plausible.Stats.Base
  import Ecto.Query

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
      |> Plausible.Imported.load_import_data()

    excluded = Keyword.get(opts, :exclude, [])

    params = %{"with_imported" => "true", "period" => "6mo"}
    query = Query.from(site, params)

    native_q =
      from(e in base_event_query(site, query),
        where: fragment("? ilike ?", e.name, ^matches),
        where: e.name != "pageview",
        where: e.name not in ^excluded,
        select: %{
          name: e.name,
          visitors: visitors(e)
        },
        group_by: e.name,
        limit: 25
      )

    imported_q =
      from(i in "imported_custom_events",
        where: i.site_id == ^site.id,
        where: i.import_id in ^site.complete_import_ids,
        where: i.date >= ^query.date_range.first and i.date <= ^query.date_range.last,
        where: i.visitors > 0,
        where: fragment("? ilike ?", i.name, ^matches),
        where: i.name not in ^excluded,
        select: %{
          name: i.name,
          visitors: selected_as(sum(i.visitors), :visitors)
        },
        group_by: i.name,
        limit: 25
      )

    from(e in Ecto.Query.subquery(native_q),
      full_join: i in subquery(imported_q),
      on: e.name == i.name,
      select: selected_as(fragment("if(empty(?), ?, ?)", e.name, i.name, e.name), :name),
      order_by: [desc: e.visitors + i.visitors],
      limit: 25
    )
    |> ClickhouseRepo.all()
    |> Enum.map(&{&1, &1})
  end
end
