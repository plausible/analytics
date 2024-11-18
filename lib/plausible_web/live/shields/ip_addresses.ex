defmodule PlausibleWeb.Live.Shields.IPAddresses do
  @moduledoc """
  LiveView for IP Addresses Shield
  """
  use PlausibleWeb, :live_view

  alias Plausible.Shields

  def mount(
        _params,
        %{
          "remote_ip" => remote_ip,
          "domain" => domain
        },
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Plausible.Teams.Adapter.Read.Sites.get_for_user!(current_user, domain, [
          :owner,
          :admin,
          :super_admin
        ])
      end)
      |> assign_new(:ip_rules_count, fn %{site: site} ->
        Shields.count_ip_rules(site)
      end)
      |> assign_new(:remote_ip, fn -> remote_ip end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.flash_messages flash={@flash} />
      <.live_component
        module={PlausibleWeb.Live.Shields.IPRules}
        current_user={@current_user}
        ip_rules_count={@ip_rules_count}
        site={@site}
        remote_ip={@remote_ip}
        id={"ip-rules-#{@current_user.id}"}
      />
    </div>
    """
  end

  def handle_info({:flash, kind, message}, socket) do
    socket = put_live_flash(socket, kind, message)
    {:noreply, socket}
  end
end
