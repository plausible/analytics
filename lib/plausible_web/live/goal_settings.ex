defmodule PlausibleWeb.Live.GoalSettings do
  @moduledoc """
  LiveView allowing listing, creating and deleting goals.
  """
  use Phoenix.LiveView
  use Phoenix.HTML

  use Plausible.Funnel

  alias Plausible.{Sites, Goals}

  def mount(
        _params,
        %{"site_id" => _site_id, "domain" => domain, "current_user_id" => user_id},
        socket
      ) do
    site = Sites.get_for_user!(user_id, domain, [:owner, :admin, :super_admin])

    goals = Goals.for_site(site, preload_funnels?: true)

    {:ok,
     assign(socket,
       site_id: site.id,
       domain: site.domain,
       all_goals: goals,
       displayed_goals: goals,
       add_goal?: false,
       current_user_id: user_id,
       filter_text: ""
     )}
  end

  # Flash sharing with live views within dead views can be done via re-rendering the flash partial.
  # Normally, we'd have to use live_patch which we can't do with views unmounted at the router it seems.
  def render(assigns) do
    ~H"""
    <div id="goal-settings-main">
      <.live_component id="embedded_liveview_flash" module={PlausibleWeb.Live.Flash} flash={@flash} />
      <%= if @add_goal? do %>
        <%= live_render(
          @socket,
          PlausibleWeb.Live.GoalSettings.Form,
          id: "goals-form",
          session: %{
            "current_user_id" => @current_user_id,
            "domain" => @domain,
            "site_id" => @site_id,
            "rendered_by" => self()
          }
        ) %>
      <% end %>
      <.live_component
        module={PlausibleWeb.Live.GoalSettings.List}
        id="goals-list"
        goals={@displayed_goals}
        domain={@domain}
        filter_text={@filter_text}
      />
    </div>
    """
  end

  def handle_event("reset-filter-text", _params, socket) do
    {:noreply, assign(socket, filter_text: "", displayed_goals: socket.assigns.all_goals)}
  end

  def handle_event("filter", %{"filter-text" => filter_text}, socket) do
    new_list =
      PlausibleWeb.Live.Components.ComboBox.StaticSearch.suggest(
        filter_text,
        socket.assigns.all_goals
      )

    {:noreply, assign(socket, displayed_goals: new_list, filter_text: filter_text)}
  end

  def handle_event("add-goal", _value, socket) do
    {:noreply, assign(socket, add_goal?: true)}
  end

  def handle_event("delete-goal", %{"goal-id" => goal_id}, socket) do
    goal_id = String.to_integer(goal_id)

    case Plausible.Goals.delete(goal_id, socket.assigns.site_id) do
      :ok ->
        socket =
          socket
          |> put_flash(:success, "Goal deleted successfully")
          |> assign(
            all_goals: Enum.reject(socket.assigns.all_goals, &(&1.id == goal_id)),
            displayed_goals: Enum.reject(socket.assigns.displayed_goals, &(&1.id == goal_id))
          )

        Process.send_after(self(), :clear_flash, 5000)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(:cancel_add_goal, socket) do
    {:noreply, assign(socket, add_goal?: false)}
  end

  def handle_info({:goal_added, goal}, socket) do
    socket =
      socket
      |> assign(
        add_goal?: false,
        filter_text: "",
        all_goals: [goal | socket.assigns.all_goals],
        displayed_goals: [goal | socket.assigns.all_goals]
      )
      |> put_flash(:success, "Goal saved successfully")

    {:noreply, socket}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end
end
