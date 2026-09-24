defmodule Plausible.Auth.Scopes do
  @moduledoc """
  This module enumerates the scopes that any particular
  authorization grant can be limited to.
  """

  @stats_read_all "stats:read:*"
  def stats_read(), do: @stats_read_all

  @sites_read_all "sites:read:*"
  def sites_read(), do: @sites_read_all
end
