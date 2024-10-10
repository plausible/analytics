defmodule PlausibleWeb.Components.Settings do
  @moduledoc """
  An umbrella module for the Integrations settings section
  """
  use PlausibleWeb, :component

  embed_templates("../templates/site/settings_search_console.html")
end
