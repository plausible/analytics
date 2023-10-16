defmodule PlausibleWeb.Components.Settings do
  @moduledoc """
  An umbrella module for the Integrations settings section
  """
  use Phoenix.Component
  use Phoenix.HTML

  embed_templates("../templates/site/settings_search_console*")
  embed_templates("../templates/site/settings_google_import*")
end
