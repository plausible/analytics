defmodule Plausible.Auth.Scopes do
  @stats_read_star "stats:read:*"
  def stats_read(), do: @stats_read_star

  @sites_read_star "sites:read:*"
  def sites_read(), do: @sites_read_star
end
