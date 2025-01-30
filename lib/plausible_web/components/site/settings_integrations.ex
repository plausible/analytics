defmodule PlausibleWeb.Components.Site.SettingsIntegrations do
  @moduledoc """
  An umbrella module exposing functions that render subsections
  under Site Settings > Integrations.
  """
  use PlausibleWeb, :component

  embed_templates("../../templates/site/settings_search_console.html")
  embed_templates("../../templates/site/settings_looker_studio.html")
end
