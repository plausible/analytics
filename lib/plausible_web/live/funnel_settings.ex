defmodule PlausibleWeb.Live.FunnelSettings do
  use Phoenix.LiveView
  use Phoenix.HTML

  alias Plausible.{Sites, Goals, Funnels}

  def mount(
        _params,
        %{"site_id" => _site_id, "domain" => domain, "current_user_id" => user_id},
        socket
      ) do
    site = Sites.get_for_user!(user_id, domain, [:owner, :admin])

    funnels = Funnels.list(site)
    goals = Goals.for_site(site)

    {:ok, assign(socket, site: site, funnels: funnels, goals: goals, add_funnel?: false)}
  end

  def render(assigns) do
    ~H"""
    <%= if @add_funnel? do %>
      <.live_component module={PlausibleWeb.Live.FunnelSettings.Form} id="funnelForm" site={@site} form={to_form(Plausible.Funnel.changeset())} goals={@goals} />
    <% else %>
      <.live_component module={PlausibleWeb.Live.FunnelSettings.List} id="funnelsList" funnels={@funnels} site={@site} />
      <button type="button" class="button mt-6" phx-click="add_funnel">+ Add funnel</button>
    <% end %>
    """
  end

  def handle_event("add_funnel", _value, socket) do
    {:noreply, assign(socket, :add_funnel?, true)}
  end

  def handle_event("cancel_add_funnel", _value, socket) do
    {:noreply, assign(socket, :add_funnel?, false)}
  end

  def handle_event("validate", value, socket) do
    IO.inspect(value, label: :validate)
    {:noreply, socket}
  end
end
