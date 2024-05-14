defmodule Plausible.Stats.Imported.Base do
  @moduledoc """
  A module for building the base of an imported stats query
  """
  alias Plausible.Stats.{Query, Imported, Filters}

  import Ecto.Query

  @goals_with_url Imported.goals_with_url()
  @goals_with_path Imported.goals_with_path()
  @special_goals @goals_with_path ++ @goals_with_url

  def query_imported(site, query) do
    query = Imported.drop_redundant_filters(query)

    query
    |> decide_table()
    |> query_imported(site, query)
  end

  def query_imported(table, site, query) do
    query = Imported.drop_redundant_filters(query)
    import_ids = site.complete_import_ids
    %{first: date_from, last: date_to} = query.date_range

    from(i in table,
      where: i.site_id == ^site.id,
      where: i.import_id in ^import_ids,
      where: i.date >= ^date_from,
      where: i.date <= ^date_to,
      select: %{}
    )
    |> apply_filter(query)
  end

  def decide_table(%Query{filters: [], property: nil}), do: "imported_visitors"
  def decide_table(%Query{filters: [], property: "event:props:url"}), do: nil
  def decide_table(%Query{filters: [], property: "event:props:path"}), do: nil

  def decide_table(%Query{filters: filters, property: "event:props:url"}) do
    case filters do
      [[:is, "event:goal", {:event, name}]] when name in @goals_with_url ->
        "imported_custom_events"

      _ ->
        nil
    end
  end

  def decide_table(%Query{filters: filters, property: "event:props:path"}) do
    case filters do
      [[:is, "event:goal", {:event, name}]] when name in @goals_with_path ->
        "imported_custom_events"

      _ ->
        nil
    end
  end

  def decide_table(%Query{filters: [], property: property}) do
    Imported.property_to_table_mappings()[property]
  end

  def decide_table(%Query{filters: [filter], property: property}) do
    [_op, filtered_prop | _] = filter
    table_candidate = Imported.property_to_table_mappings()[filtered_prop]

    cond do
      is_nil(property) -> table_candidate
      property == filtered_prop -> table_candidate
      true -> nil
    end
  end

  def decide_table(_query_with_more_than_one_filter), do: nil

  defp apply_filter(q, %Query{filters: [[:is, "event:goal", {:event, name}]]})
       when name in @special_goals do
    where(q, [i], i.name == ^name)
  end

  defp apply_filter(_q, %Query{filters: [[_, "event:goal" | _]]}) do
    # TODO: implement and test.
    raise "Unimplemented"
  end

  defp apply_filter(q, %Query{filters: [[_, filtered_prop | _] = filter]}) do
    db_field = Plausible.Stats.Filters.without_prefix(filtered_prop)
    condition = Filters.WhereBuilder.build_condition(db_field, filter)

    where(q, ^condition)
  end

  defp apply_filter(q, _), do: q
end
