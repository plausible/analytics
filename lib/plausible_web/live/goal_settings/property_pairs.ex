defmodule PlausibleWeb.Live.GoalSettings.PropertyPairs do
  @moduledoc """
  LiveComponent for managing multiple custom property name + value pairs
  """
  use PlausibleWeb, :live_component

  alias PlausibleWeb.Live.GoalSettings.PropertyPairInput

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:max_slots, fn -> Plausible.Goal.max_custom_props_per_goal() end)
      |> assign_new(:slots, fn
        %{goal: goal} ->
          if Plausible.Goal.has_custom_props?(goal) do
            to_list_with_ids(goal.custom_props)
          else
            to_list_with_ids(empty_row())
          end
      end)

    {:ok, socket}
  end

  attr(:goal, Plausible.Goal, default: nil)
  attr(:site, Plausible.Site)

  def render(assigns) do
    ~H"""
    <div data-test-id="custom-property-pairs">
      <div
        :for={{id, {prop_key, prop_value}} <- @slots}
        class="flex items-center gap-2 mb-2"
      >
        <div class="flex-1">
          <.live_component
            id={"property_pair_#{id}"}
            module={PropertyPairInput}
            site={@site}
            initial_prop_key={prop_key}
            initial_prop_value={prop_value}
          />
        </div>

        <div class="w-min inline-flex items-center align-middle">
          <.remove_property_button
            :if={length(@slots) > 1}
            pair_id={id}
            myself={@myself}
          />
        </div>
      </div>

      <a
        :if={length(@slots) < @max_slots}
        class="text-indigo-500 text-sm font-medium cursor-pointer"
        phx-click="add-slot"
        phx-target={@myself}
      >
        + Add another property
      </a>
    </div>
    """
  end

  attr(:pair_id, :string, required: true)
  attr(:myself, :any, required: true)

  def remove_property_button(assigns) do
    ~H"""
    <div class="inline-flex items-center text-red-500" data-test-id={"remove-property-#{@pair_id}"}>
      <svg
        id={"remove-property-#{@pair_id}"}
        class="feather feather-sm cursor-pointer"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        phx-click="remove-slot"
        phx-value-pair-id={@pair_id}
        phx-target={@myself}
      >
        <polyline points="3 6 5 6 21 6"></polyline>
        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2">
        </path>
        <line x1="10" y1="11" x2="10" y2="17"></line>
        <line x1="14" y1="11" x2="14" y2="17"></line>
      </svg>
    </div>
    """
  end

  def handle_event("add-slot", _, socket) do
    slots = socket.assigns.slots ++ to_list_with_ids(empty_row())
    {:noreply, assign(socket, slots: slots)}
  end

  def handle_event("remove-slot", %{"pair-id" => id}, socket) do
    slots = List.keydelete(socket.assigns.slots, id, 0)
    {:noreply, assign(socket, slots: slots)}
  end

  defp to_list_with_ids(custom_props_map) do
    Enum.into(custom_props_map, [], fn {k, v} -> {Ecto.UUID.generate(), {k, v}} end)
  end

  defp empty_row() do
    %{"" => ""}
  end
end
