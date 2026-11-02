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

    socket =
      socket
      |> assign(:current_path, current_path)
      |> assign_new(:has_guest_sites?, fn %{current_user: user} ->
        Plausible.Teams.Memberships.has_guest_memberships?(user)
      end)

    {:cont, socket}
  end
end
