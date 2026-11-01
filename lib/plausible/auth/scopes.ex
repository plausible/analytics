defmodule Plausible.Auth.Scopes do
  @moduledoc """
  This module enumerates the scopes that any particular
  authorization grant can be limited to.
  """

  @stats_read_all "stats:read:*"
  def stats_read(), do: @stats_read_all

  @sites_read_all "sites:read:*"
  def sites_read(), do: @sites_read_all

  @descriptions %{
    @stats_read_all => "Read your sites' analytics (Stats API)",
    @sites_read_all => "Read the list and details of your sites"
  }

  @doc """
  Renders a scope as the line shown on an OAuth consent screen, falling back to
  the raw scope if it has no description.
  """
  def description(scope), do: Map.get(@descriptions, scope, scope)
end
