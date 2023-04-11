defmodule Plausible.Site.Removal do
  @moduledoc """
  A site deletion service stub.
  """
  alias Plausible.Repo

  import Ecto.Query

  @spec run(String.t()) :: {:ok, map()}
  def run(domain) do
    result = Repo.delete_all(from(s in Plausible.Site, where: s.domain == ^domain))
    {:ok, %{delete_all: result}}
  end
end
