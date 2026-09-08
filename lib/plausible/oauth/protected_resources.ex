defmodule Plausible.OAuth.ProtectedResources do
  @moduledoc """
  The protected resources the OAuth authorization server will issue tokens for.
  Each authorization grant is associated with a particular resource.
  """

  def mcp(),
    do: %{
      resource_path: "/mcp",
      scopes_supported: [Plausible.Auth.Scopes.sites_read()]
    }
end
