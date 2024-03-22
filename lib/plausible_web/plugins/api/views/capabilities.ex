defmodule PlausibleWeb.Plugins.API.Views.Capabilities do
  @moduledoc """
  View for rendering Capabilities on the Plugins API
  """
  use PlausibleWeb, :plugins_api_view

  def render("index.json", %{capabilities: capabilities}) when is_map(capabilities) do
    capabilities
  end
end
