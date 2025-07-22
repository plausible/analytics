defmodule Plausible.Audit do
  @moduledoc """
  Primary persistent Audit Entry interface
  """

  import Ecto.Query

  defdelegate encode(term, opts \\ []), to: Plausible.Audit.Encoder
  defdelegate set_context(term), to: Plausible.Audit.Entry

  def list_entries(attrs) do
    Plausible.Repo.all(
      from ae in Plausible.Audit.Entry, where: ^attrs, order_by: [asc: :datetime]
    )
  end
end
