defmodule PlausibleWeb.OAuthView do
  # Mirrors the `PlausibleWeb, :view` macro but pins the template `path` to
  # "oauth" (the default derivation would underscore `OAuth` to "o_auth").
  use Phoenix.View, root: "lib/plausible_web/templates", path: "oauth"

  use Phoenix.Component, global_prefixes: ~w(x-)

  import PlausibleWeb.Components.Generic

  @scope_descriptions %{
    "stats:read:*" => "Read your sites' analytics (Stats API)",
    "sites:read:*" => "Read the list and details of your sites"
  }

  def scope_description(scope) do
    Map.get(@scope_descriptions, scope, scope)
  end
end
