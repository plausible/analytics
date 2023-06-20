defmodule PlausibleWeb.Live.FunnelSettings do
  @moduledoc """
  LiveView allowing listing, creating and deleting funnels.
  """
  use Phoenix.LiveView
  use Phoenix.HTML

  use Plausible.Funnel

  alias Plausible.{Sites, Goals, Funnels}

  def mount(
        _params,
        %{"site_id" => _site_id, "domain" => domain, "current_user_id" => user_id},
        socket
      ) do
    true = Plausible.Funnels.enabled_for?("user:#{user_id}")
    site = Sites.get_for_user!(user_id, domain, [:owner, :admin])

    funnels = Funnels.list(site)

    # We'll have the options trimmed to only the data we care about, to keep
    # it minimal at the socket assigns, yet, we want to retain specific %Goal{}
    # fields, so that `String.Chars` protocol and `Funnels.ephemeral_definition/3`
    # are applicable downstream.
    goals =
      site
      |> Goals.for_site()
      |> Enum.map(fn goal ->
        {goal.id, struct!(Plausible.Goal, Map.take(goal, [:id, :event_name, :page_path]))}
      end)

    {:ok, assign(socket, site: site, funnels: funnels, goals: goals, add_funnel?: false)}
  end

  # Flash sharing with live views within dead views can be done via re-rendering the flash partial.
  # Normally, we'd have to use live_patch which we can't do with views unmounted at the router it seems.
  def render(assigns) do
    ~H"""
    <div>
      <.live_component id="embedded_liveview_flash" module={PlausibleWeb.Live.Flash} flash={@flash} />
      <%= if @add_funnel? do %>
        <.live_component
          module={PlausibleWeb.Live.FunnelSettings.Form}
          id="funnel-form"
          site={@site}
          form={to_form(Plausible.Funnels.create_changeset(@site, "", []))}
          goals={@goals}
        />
      <% else %>
        <div :if={Enum.count(@goals) >= Funnel.min_steps()}>
          <.live_component
            module={PlausibleWeb.Live.FunnelSettings.List}
            id="funnels-list"
            funnels={@funnels}
            site={@site}
          />
          <button type="button" class="button mt-6" phx-click="add-funnel">+ Add funnel</button>
        </div>

        <div :if={Enum.count(@goals) < Funnel.min_steps()}>
          <PlausibleWeb.Components.Generic.notice>
            You need to define at least two goals to create a funnel. Go ahead and <%= link(
              "add goals",
              to: PlausibleWeb.Router.Helpers.site_path(@socket, :new_goal, @site.domain),
              class: "text-indigo-500 w-full text-center"
            ) %> to proceed.
          </PlausibleWeb.Components.Generic.notice>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("add-funnel", _value, socket) do
    {:noreply, assign(socket, add_funnel?: true)}
  end

  def handle_event("cancel-add-funnel", _value, socket) do
    {:noreply, assign(socket, add_funnel?: false)}
  end

  def handle_event("delete-funnel", %{"funnel-id" => id}, socket) do
    id = String.to_integer(id)
    :ok = Funnels.delete(socket.assigns.site, id)
    socket = put_flash(socket, :success, "Funnel deleted successfully")
    Process.send_after(self(), :clear_flash, 5000)
    {:noreply, assign(socket, funnels: Funnels.list(socket.assigns.site))}
  end

  def handle_info({:funnel_saved, funnel}, socket) do
    socket = put_flash(socket, :success, "Funnel saved successfully")
    Process.send_after(self(), :clear_flash, 5000)
    {:noreply, assign(socket, add_funnel?: false, funnels: [funnel | socket.assigns.funnels])}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end
end
