defmodule PlausibleWeb.Live.FunnelSettings.ComboBox do
  @moduledoc """
  Phoenix LiveComponent for a combobox UI element with search and selection
  functionality.

  The component allows users to select an option from a list of options,
  which can be searched by typing in the input field.

  The component renders an input field with a dropdown anchor and a
  hidden input field for submitting the selected value.

  The number of options displayed in the dropdown is limited to 15
  by default but can be customized. When a user types into the input
  field, the component searches the available options and provides
  suggestions based on the input.
  """
  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS

  @max_options_displayed 15

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:suggestions, fn ->
        Enum.take(assigns.options, @max_options_displayed)
      end)

    {:ok, socket}
  end

  attr(:placeholder, :string, default: "Select option or search by typing")
  attr(:id, :any, required: true)
  attr(:options, :list, required: true)
  attr(:submit_name, :string, required: true)
  attr(:display_value, :string, default: "")
  attr(:submit_value, :string, default: "")

  def render(assigns) do
    ~H"""
    <div
      id={"input-picker-main-#{@id}"}
      class="mb-3"
      x-data={"window.suggestionsDropdown('#{@id}')"}
      x-on:keydown.arrow-up="focusPrev"
      x-on:keydown.arrow-down="focusNext"
      x-on:keydown.enter="select()"
      x-on:keydown.tab="close"
    >
      <div class="relative w-full">
        <div
          @click.away="close"
          class="pl-2 pr-8 py-1 w-full dark:bg-gray-900 dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500"
        >
          <input
            type="text"
            autocomplete="off"
            id={@id}
            name={"display-#{@id}"}
            placeholder={@placeholder}
            x-on:focus="open"
            phx-change="search"
            phx-target={@myself}
            value={@display_value}
            class="border-none py-1 px-1 p-0 w-full inline-block rounded-md focus:outline-none focus:ring-0 text-sm"
            style="background-color: inherit;"
          />

          <.dropdown_anchor id={@id} />

          <input
            type="hidden"
            name={@submit_name}
            value={@submit_value}
            phx-target={@myself}
            id={"submit-#{@id}"}
          />
        </div>
      </div>

      <.dropdown ref={@id} options={@options} suggestions={@suggestions} target={@myself} />
    </div>
    """
  end

  attr(:id, :any, required: true)

  def dropdown_anchor(assigns) do
    ~H"""
    <div x-on:click="open" class="cursor-pointer absolute inset-y-0 right-0 flex items-center pr-2">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
        class="h-4 w-4 text-gray-500"
      >
        <path
          fill-rule="evenodd"
          d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
          clip-rule="evenodd"
        >
        </path>
      </svg>
    </div>
    """
  end

  attr(:ref, :string, required: true)
  attr(:options, :list, default: [])
  attr(:suggestions, :list, default: [])
  attr(:target, :any)

  def dropdown(assigns) do
    ~H"""
    <ul
      tabindex="-1"
      id={"dropdown-#{@ref}"}
      x-show="isOpen"
      x-ref="suggestions"
      class="dropdown z-50 absolute mt-1 max-h-60 overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm dark:bg-gray-900"
    >
      <.option
        :for={
          {{submit_value, display_value}, idx} <-
            Enum.with_index(
              @suggestions,
              fn {option_value, option}, idx -> {{option_value, to_string(option)}, idx} end
            )
        }
        :if={@suggestions != []}
        idx={idx}
        submit_value={submit_value}
        display_value={display_value}
        target={@target}
        ref={@ref}
      />

      <div
        :if={@suggestions == []}
        class="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300"
      >
        No matches found. Try searching for something different.
      </div>
    </ul>
    """
  end

  attr(:display_value, :string, required: true)
  attr(:submit_value, :integer, required: true)
  attr(:ref, :string, required: true)
  attr(:target, :any)
  attr(:idx, :integer, required: true)

  def option(assigns) do
    assigns = assign(assigns, :max_options_displayed, @max_options_displayed)

    ~H"""
    <li
      class="relative select-none cursor-pointer dark:text-gray-300"
      @mouseenter={"setFocus(#{@idx})"}
      x-bind:class={ "{'text-white bg-indigo-500': focus === #{@idx}}" }
      id={"dropdown-#{@ref}-option-#{@idx}"}
    >
      <a
        x-ref={"dropdown-#{@ref}-option-#{@idx}"}
        phx-click={select_option(@ref, @submit_value, @display_value)}
        phx-value-display-value={@display_value}
        phx-target={@target}
        class="block py-2 px-3"
      >
        <span class="block truncate">
          <%= @display_value %>
        </span>
      </a>
    </li>
    <li :if={@idx == @max_options_displayed - 1} class="text-xs text-gray-500 relative py-2 px-3">
      Max results reached. Refine your search by typing in goal name.
    </li>
    """
  end

  def select_option(js \\ %JS{}, _id, submit_value, display_value) do
    js
    |> JS.push("select-option",
      value: %{"submit-value" => submit_value, "display-value" => display_value}
    )
  end

  def handle_event(
        "select-option",
        %{"submit-value" => submit_value, "display-value" => display_value},
        socket
      ) do
    socket = do_select(socket, submit_value, display_value)
    {:noreply, socket}
  end

  def handle_event("search", %{"_target" => [target]} = params, socket) do
    input = params[target]
    input_len = input |> String.trim() |> String.length()

    if input_len > 0 do
      suggestions = suggest(input, socket.assigns.options)
      {:noreply, assign(socket, %{suggestions: suggestions})}
    else
      {:noreply, socket}
    end
  end

  def suggest(input, options) do
    input_len = String.length(input)

    options
    |> Enum.reject(fn {_, value} ->
      input_len > String.length(to_string(value))
    end)
    |> Enum.sort_by(
      fn {_, value} ->
        if to_string(value) == input do
          3
        else
          value = to_string(value)
          input = String.downcase(input)
          value = String.downcase(value)
          weight = if String.contains?(value, input), do: 1, else: 0
          weight + String.jaro_distance(value, input)
        end
      end,
      :desc
    )
    |> Enum.take(@max_options_displayed)
  end

  defp do_select(socket, submit_value, display_value) do
    id = socket.assigns.id

    socket =
      socket
      |> push_event("update-value", %{id: id, value: display_value, fire: false})
      |> push_event("update-value", %{id: "submit-#{id}", value: submit_value, fire: true})
      |> assign(:display_value, display_value)
      |> assign(:submit_value, submit_value)

    send(
      self(),
      {:selection_made,
       %{
         by: id,
         submit_value: submit_value
       }}
    )

    socket
  end
end
