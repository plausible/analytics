defmodule Plausible.Site.Cache.Warmer.All do
  @moduledoc """
  A Cache.Warmer adapter that refreshes the Sites Cache fully.
  This module exists only to make it explicit what the warmer
  refreshes, to be used in the supervisor tree.
  """
  defdelegate child_spec(opts), to: Plausible.Site.Cache.Warmer
end
