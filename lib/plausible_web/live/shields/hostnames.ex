defmodule PlausibleWeb.Live.Shields.Hostnames do
  @moduledoc """
  LiveView for Hostnames Shield
  """
  use PlausibleWeb, :live_view

  alias Plausible.Shields

  def mount(_params, %{"domain" => domain}, socket) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Plausible.Sites.get_for_user!(current_user, domain, [
          :owner,
          :admin,
          :editor,
          :super_admin
        ])
      end)
      |> assign_new(:hostname_rules_count, fn %{site: site} ->
        Shields.count_hostname_rules(site)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.flash_messages flash={@flash} />
      <.live_component
        module={PlausibleWeb.Live.Shields.HostnameRules}
        current_user={@current_user}
        hostname_rules_count={@hostname_rules_count}
        site={@site}
        id={"hostname-rules-#{@current_user.id}"}
      />
    </div>
    """
  end

  def handle_info({:flash, kind, message}, socket) do
    socket = put_live_flash(socket, kind, message)
    {:noreply, socket}
  end
end
