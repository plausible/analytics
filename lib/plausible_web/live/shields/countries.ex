defmodule PlausibleWeb.Live.Shields.Countries do
  @moduledoc """
  LiveView for IP Addresses Shield
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Shields
  alias Plausible.Sites

  def mount(
        _params,
        %{"domain" => domain},
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Sites.get_for_user!(current_user, domain, [:owner, :admin, :super_admin])
      end)
      |> assign_new(:country_rules_count, fn %{site: site} ->
        Shields.count_country_rules(site)
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.flash_messages flash={@flash} />
      <.live_component
        module={PlausibleWeb.Live.Shields.CountryRules}
        current_user={@current_user}
        country_rules_count={@country_rules_count}
        site={@site}
        id={"country-rules-#{@current_user.id}"}
      />
    </div>
    """
  end

  def handle_info({:flash, kind, message}, socket) do
    socket = put_live_flash(socket, kind, message)
    {:noreply, socket}
  end
end
