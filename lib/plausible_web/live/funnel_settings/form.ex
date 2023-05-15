defmodule PlausibleWeb.Live.FunnelSettings.Form do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  # good

  def mount(socket) do
    {:ok, assign(socket, step_count: 2)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, form: assigns.form, goals: assigns.goals)}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-4 gap-6 mt-6">
      <div class="col-span-4 sm:col-span-2">
        <.form :let={f} for={@form} phx-change="validate" phx-submit="save">
        <%= label f, "Funnel name", class: "block text-sm font-medium text-gray-700 dark:text-gray-300" %>
        <.input field={@form[:name]} />

        <%= label f, "Funnel Steps", class: "mt-6 block text-sm font-medium text-gray-700 dark:text-gray-300" %>

        <%= for _step_number <- 1..@step_count do %>
          <.select goals={@goals} myself={@myself} />
        <% end %>

        <%= if @step_count < 5 do %>
          <a class="underline text-indigo-600 cursor-pointer" phx-click="add-step" phx-target={@myself}>Add another step</a>
        <% end %>

    <br/><hr/>

        <button type="button" class="button mt-6">Save</button>
        <button type="button" class="button mt-6" phx-click="cancel_add_funnel">Cancel</button>
    </.form>
      </div>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField

  def input(assigns) do
    ~H"""
    <input type="text" id={@field.id} name={@field.name} value={@field.value} class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-full rounded-md sm:text-sm border-gray-300 dark:border-gray-500" />
    """
  end

  attr :goals, :map, required: true
  attr :myself, :any, required: true

  def select(assigns) do
    ~H"""
    <select phx-change="changed" phx-target={@myself} name="steps[]" class="dark:bg-gray-900 mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 dark:border-gray-500 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md dark:text-gray-100 cursor-pointer" id="site_timezone">
    <%= for goal <- @goals do %>
      <option value={goal.id}>
        <%= Plausible.Goal.display_name(goal) %>
      </option>
    <% end %>
    </select>
    """
  end

  def handle_event("add-step", _value, socket) do
    step_count = socket.assigns.step_count

    if step_count < 5 do
      {:noreply, assign(socket, step_count: step_count + 1)}
    else
      {:noreply, socket}
    end
  end

  def handle_event(event, value, socket) do
    IO.inspect(event, label: :event)
    IO.inspect(value, label: :value)
    [_ | except_first] = socket.assigns.goals
    {:noreply, assign(socket, goals: except_first)}
  end
end

# goal_options = [{"N/A", ""} | Enum.map(@goals, fn goal -> {Plausible.Goal.display_name(goal), goal.id} end)] %>
#
# end
