defmodule PlausibleWeb.Live.FunnelSettings.InputPicker do
  use Phoenix.LiveComponent

  attr :placeholder, :string, default: "Select a Goal"
  attr :id, :any, default: nil
  attr :options, :list, default: []
  attr :choices, :list, default: nil
  attr :show_picker?, :boolean, default: false
  attr :value, :string, default: ""
  attr :goal_id, :string, default: ""
  attr :higlighted, :integer, default: nil

  ## XXX handle phx-blur properly on tab
  def render(assigns) do
    ~H"""
    <div class="mb-3">
    <div class="relative w-full">
      <div class="pl-2 pr-8 py-1 w-full dark:bg-gray-900 dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 ">


        <input autocomplete="off" phx-debounce="10" phx-keyup="keypress" phx-click="show-picker" phx-target={@myself} name={@id} id={@id} class="border-none py-1 px-1 p-0 w-full inline-block rounded-md focus:outline-none focus:ring-0 text-sm" style="background-color: inherit;" placeholder={@placeholder} type="text" value={@value}>

        <div phx-click="show-picker" phx-target={@myself} class="cursor-pointer absolute inset-y-0 right-0 flex items-center pr-2">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true" class="h-4 w-4 text-gray-500"><path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd"></path></svg>
        </div>

      </div>
    </div>

    <.picker id={"picker-#{@id}"} :if={@show_picker?} options={@options} choices={@choices || @options} target={@myself} higlighted={@higlighted} />
    </div>
    """
  end

  attr :id, :any, default: nil
  attr :options, :list, default: []
  attr :choices, :list, default: []
  attr :higlighted, :any
  attr :target, :any

  def picker(assigns) do
    ~H"""
    <ul phx-click-away="hide-picker" phx-target={@target} class="z-50 absolute mt-1 max-h-60 overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm dark:bg-gray-900">
    <%= if @choices != [] do %>
      <%= for {goal_id, goal_name} <- @choices do %>
        <.li goal_id={goal_id} goal_name={goal_name} target={@target} higlighted={@higlighted}/>
      <% end %>
    <% else %>
        <div class="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300">No matches found in the current goals. Try searching for something different.</div>
    <% end %>
    </ul>
    """
  end

  attr :higlighted, :any, default: nil
  attr :goal_name, :string, required: true
  attr :goal_id, :integer, required: true
  attr :target, :any

  def li(assigns) do
    ~H"""
    <%= if @higlighted == @goal_id do %>
      <li phx-value-goal-name={@goal_name}, phx-click="selected" phx-target={@target} class="relative select-none py-2 px-3 cursor-pointer dark:text-gray-300 bg-indigo-500 text-white">
        <span class="block truncate"><%= @goal_name %></span>
      </li>
    <% else %>
      <li phx-value-goal-name={@goal_name}, phx-click="selected" phx-target={@target} class="relative select-none py-2 px-3 cursor-pointer dark:text-gray-300 text-gray-500">
        <span class="block truncate"><%= @goal_name %></span>
      </li>
    <% end %>
    """
  end

  def handle_event("selected", %{"goal-name" => goal_name}, socket) do
    send(self(), :goal_picked)
    {:noreply, assign(socket, %{show_picker?: false, value: goal_name})}
  end

  def handle_event("keypress", %{"key" => "ArrowDown"}, socket) do
    choices = socket.assigns.choices
    current = socket.assigns.higlighted

    next =
      Enum.drop_while(choices, fn {id, _} -> id != current end)
      |> Enum.take(2)
      |> List.last()

    higlighted =
      case next do
        {next_id, _} ->
          next_id

        nil ->
          current
      end

    {:noreply, assign(socket, %{higlighted: higlighted, show_picker?: true})}
  end

  def handle_event("keypress", %{"key" => "ArrowUp"}, socket) do
    choices = socket.assigns.choices
    current = socket.assigns.higlighted

    next =
      choices
      |> Enum.reverse()
      |> Enum.drop_while(fn {id, _} -> id != current end)
      |> Enum.take(2)
      |> List.last()

    higlighted =
      case next do
        {next_id, _} ->
          next_id

        nil ->
          current
      end

    {:noreply, assign(socket, %{higlighted: higlighted, show_picker?: true})}
  end

  def handle_event("keypress", %{"key" => "Enter"}, socket) do
    choices = socket.assigns.choices
    current = socket.assigns.higlighted

    goal_name =
      Enum.find_value(choices, fn {id, goal_name} ->
        if id == current, do: goal_name
      end)

    socket =
      socket
      |> assign(%{show_picker?: false, value: goal_name, higlighted: nil})
      |> push_event("update-value", %{id: socket.assigns.id, value: goal_name})

    {:noreply, socket}
  end

  def handle_event("keypress", %{"key" => _other, "value" => typed}, socket) do
    if String.length(typed) > 0 do
      choices =
        Enum.filter(socket.assigns.options, fn {_id, goal_name} ->
          String.contains?(goal_name, typed) ||
            String.jaro_distance(String.upcase(goal_name), String.upcase(typed)) > 0.6
        end)
        |> Enum.sort_by(fn {_id, goal_name} -> String.jaro_distance(goal_name, typed) end, :desc)
        |> Enum.take(10)

      first_id =
        case List.first(choices) do
          {id, _} -> id
          nil -> nil
        end

      {:noreply, assign(socket, %{choices: choices, show_picker?: true, higlighted: first_id})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("hide-picker", _, socket) do
    {:noreply, assign(socket, %{show_picker?: false})}
  end

  def handle_event("show-picker", _, socket) do
    socket =
      if socket.assigns[:choices] == [] do
        assign(socket, %{show_picker?: true, choices: socket.assigns.options})
      else
        assign(socket, %{show_picker?: true})
      end

    {:noreply, socket}
  end

  def handle_event(event, payload, socket) do
    IO.inspect(event, label: :event)
    IO.inspect(payload, label: :payload)
    {:noreply, socket}
  end
end
