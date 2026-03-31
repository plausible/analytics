defmodule PlausibleWeb.Live.SettingsContext do
  @moduledoc false

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(_arg, _params, _session, socket) do
    socket = attach_hook(socket, :get_current_path, :handle_params, &get_current_path/3)
    {:cont, socket, layout: {PlausibleWeb.LayoutView, :settings}}
  end

  defp get_current_path(_params, url, socket) do
    %{path: current_path} = URI.parse(url)
    {:cont, assign(socket, :current_path, current_path)}
  end
end
