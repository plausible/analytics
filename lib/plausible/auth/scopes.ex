defmodule Plausible.Auth.Scopes do
  @moduledoc """
  This module enumerates the scopes that any particular
  authorization grant can be limited to.
  """

  @stats_read_star "stats:read:*"
  def stats_read(), do: @stats_read_star

  @sites_read_star "sites:read:*"
  def sites_read(), do: @sites_read_star
end
