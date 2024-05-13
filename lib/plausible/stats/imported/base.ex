defmodule Plausible.Stats.Imported.Base do
  @moduledoc """
  A module for building the base of an imported stats query
  """

  import Ecto.Query

  def query_imported(table, site, query) do
    import_ids = site.complete_import_ids
    %{first: date_from, last: date_to} = query.date_range

    from(i in table,
      where: i.site_id == ^site.id,
      where: i.import_id in ^import_ids,
      where: i.date >= ^date_from,
      where: i.date <= ^date_to,
      select: %{}
    )
  end
end
