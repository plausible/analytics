defmodule PlausibleWeb.Live.Shields.Tabs do
  @moduledoc """
  Currently only a placeholder module. Once more shields
  are implemented it will display tabs with counters,
  linking to their respective live views.
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Shields
  alias Plausible.Sites

  def mount(
        _params,
        %{
          "remote_ip" => remote_ip,
          "domain" => domain,
          "current_user_id" => user_id
        },
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn ->
        Sites.get_for_user!(user_id, domain, [:owner, :admin, :super_admin])
      end)
      |> assign_new(:ip_rules_count, fn %{site: site} ->
        Shields.count_ip_rules(site)
      end)
      |> assign_new(:current_user, fn ->
        Plausible.Repo.get(Plausible.Auth.User, user_id)
      end)
      |> assign_new(:remote_ip, fn -> remote_ip end)
      |> assign(:current_tab, :ip_rules)

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
        id="ip-rules-#{@current_user.id}"
      />
    </div>
    """
  end

  def handle_info({:flash, kind, message}, socket) do
    socket = put_live_flash(socket, kind, message)
    {:noreply, socket}
  end
end
