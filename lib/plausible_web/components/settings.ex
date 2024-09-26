defmodule PlausibleWeb.Components.Settings do
  @moduledoc """
  An umbrella module for the Integrations settings section
  """
  use Phoenix.Component
  use Phoenix.HTML

  import PlausibleWeb.Components.Generic
  alias PlausibleWeb.Router.Helpers, as: Routes

  embed_templates("../templates/site/settings_search_console.html")
end
