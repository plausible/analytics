defmodule Plausible.Audit do
  @moduledoc """
  Primary persistent Audit Entry interface
  """

  import Ecto.Query

  defdelegate encode(term, opts \\ []), to: Plausible.Audit.Encoder
  defdelegate set_context(term), to: Plausible.Audit.Entry

  def list_entries(attrs) do
    attrs
    |> entries_query()
    |> Plausible.Repo.all()
  end

  def list_entries_paginated(attrs, params \\ %{}) do
    attrs
    |> entries_query()
    |> Plausible.Pagination.paginate(params, cursor_fields: [{:datetime, :asc}])
  end

  defp entries_query(attrs) do
    from ae in Plausible.Audit.Entry,
      where: ^attrs,
      order_by: [asc: :datetime]
  end
end
