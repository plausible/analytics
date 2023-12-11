defmodule PlausibleWeb.Components.Settings do
  @moduledoc """
  An umbrella module for the Integrations settings section
  """
  use Phoenix.Component
  use Phoenix.HTML
  use Phoenix.VerifiedRoutes, endpoint: PlausibleWeb.Endpoint, router: PlausibleWeb.Router

  import PlausibleWeb.Components.Generic

  embed_templates("../templates/site/settings_search_console.html")
  embed_templates("../templates/site/settings_google_import.html")
  embed_templates("../templates/site/settings_wip_export.html")
end
