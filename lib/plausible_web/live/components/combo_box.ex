defmodule PlausibleWeb.Live.Components.ComboBox do
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

  Any function can be supplied via `suggest_fun` attribute
  - see the provided `ComboBox.StaticSearch`.

  In most cases the `suggest_fun` runs an operation that could be deferred,
  so by default, the `async={true}` attr calls it in a background Task
  and updates the suggestions asynchronously. This way, you can render
  the component without having to wait for suggestions to load.

  If you explicitly need to make the operation synchronous, you may
  pass `async={false}` option.

  If your initial `options` are not provided up-front at initial render,
  lack of `options` attr value combined with `async=true` calls the
  `suggest_fun.("", [])` asynchronously - that special clause can be used
  to provide the initial set of suggestions updated right after the initial render.

  To simplify integration testing, suggestions load up synchronously during
  tests. This lets you skip waiting for suggestions messages
  to arrive. The asynchronous behaviour alone is already tested in
  ComboBox own test suite, so there is no need for additional
  verification.
  """
  use Phoenix.LiveComponent, global_prefixes: ~w(x-)
  alias Phoenix.LiveView.JS

  @default_suggestions_limit 15

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> select_default()

    socket =
      if connected?(socket) do
        socket
        |> assign_options()
        |> assign_suggestions()
      else
        socket
      end

    {:ok, socket}
  end

  attr(:placeholder, :string, default: "Select option or search by typing")
  attr(:id, :any, required: true)
  attr(:options, :list, default: [])
  attr(:submit_name, :string, required: true)
  attr(:display_value, :string, default: "")
  attr(:submit_value, :string, default: "")
  attr(:selected, :any)
  attr(:suggest_fun, :any, required: true)
  attr(:suggestions_limit, :integer)
  attr(:class, :string, default: "")
  attr(:required, :boolean, default: false)
  attr(:creatable, :boolean, default: false)
  attr(:errors, :list, default: [])
  attr(:async, :boolean, default: Mix.env() != :test)
  attr(:on_selection_made, :any)

  def render(assigns) do
    assigns =
      assign_new(assigns, :suggestions, fn ->
        Enum.take(assigns.options, suggestions_limit(assigns))
      end)

    ~H"""
    <div
      id={"input-picker-main-#{@id}"}
      class={@class}
      x-data={"comboBox('#{@id}')"}
      x-on:keydown.arrow-up.prevent="focusPrev"
      x-on:keydown.arrow-down.prevent="focusNext"
      x-on:keydown.enter.prevent="select"
      x-on:keydown.tab="close"
      x-on:keydown.escape="close"
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
            x-on:selection-change={assigns[:"x-on-selection-change"]}
            phx-change="search"
            x-on:keydown="open"
            phx-target={@myself}
            phx-debounce={200}
            value={@display_value}
            class="text-sm [&.phx-change-loading+svg.spinner]:block border-none py-1 px-1 p-0 w-full inline-block rounded-md focus:outline-none focus:ring-0"
            style="background-color: inherit;"
            required={@required}
          />

          <PlausibleWeb.Components.Generic.spinner class="spinner hidden absolute inset-y-3 right-8" />
          <PlausibleWeb.Components.Generic.spinner
            x-show="selectionInProgress"
            class="spinner absolute inset-y-3 right-8"
          />

          <.dropdown_anchor id={@id} />

          <input
            type="hidden"
            x-init={"trackSubmitValueChange('#{Phoenix.HTML.javascript_escape(to_string(@submit_value))}')"}
            name={@submit_name}
            value={@submit_value}
            phx-target={@myself}
            id={"submit-#{@id}"}
          />
        </div>

        <.dropdown
          ref={@id}
          suggest_fun={@suggest_fun}
          suggestions={@suggestions}
          target={@myself}
          creatable={@creatable}
          display_value={@display_value}
        />
      </div>
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
  attr(:suggestions, :list, default: [])
  attr(:suggest_fun, :any, required: true)
  attr(:target, :any)
  attr(:creatable, :boolean, required: true)
  attr(:display_value, :string, required: true)

  def dropdown(assigns) do
    ~H"""
    <ul
      tabindex="-1"
      id={"dropdown-#{@ref}"}
      x-show="isOpen"
      x-ref="suggestions"
      class="text-sm w-full dropdown z-50 absolute mt-1 max-h-60 overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none dark:bg-gray-900"
    >
      <.option
        :if={display_creatable_option?(assigns)}
        idx={0}
        submit_value={@display_value}
        display_value={@display_value}
        target={@target}
        ref={@ref}
        creatable
      />

      <.option
        :for={
          {{submit_value, display_value}, idx} <-
            Enum.with_index(
              @suggestions,
              fn {option_value, option}, idx -> {{option_value, to_string(option)}, idx + 1} end
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
        :if={@suggestions == [] && !@creatable}
        class="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300"
      >
        No matches found. Try searching for something different.
      </div>
      <div
        :if={@suggestions == [] && @creatable && String.trim(@display_value) == ""}
        class="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300"
      >
        Create an item by typing.
      </div>
    </ul>
    """
  end

  attr(:display_value, :string, required: true)
  attr(:submit_value, :string, required: true)
  attr(:ref, :string, required: true)
  attr(:target, :any)
  attr(:idx, :integer, required: true)
  attr(:creatable, :boolean, default: false)

  def option(assigns) do
    assigns = assign(assigns, :suggestions_limit, suggestions_limit(assigns))

    ~H"""
    <li
      class={[
        "relative select-none cursor-pointer dark:text-gray-300",
        @creatable && "creatable"
      ]}
      @mouseenter={"setFocus(#{@idx})"}
      x-bind:class={ "{'text-white bg-indigo-500': focus === #{@idx}}" }
      id={"dropdown-#{@ref}-option-#{@idx}"}
    >
      <a
        x-ref={"dropdown-#{@ref}-option-#{@idx}"}
        x-on:click={not @creatable && "selectionInProgress = true"}
        phx-click={select_option(@ref, @submit_value, @display_value)}
        phx-value-submit-value={@submit_value}
        phx-value-display-value={@display_value}
        phx-target={@target}
        class="block truncate py-2 px-3"
      >
        <%= if @creatable do %>
          Create "<%= @display_value %>"
        <% else %>
          <%= @display_value %>
        <% end %>
      </a>
    </li>
    <div :if={@idx == @suggestions_limit} class="text-xs text-gray-500 relative py-2 px-3">
      Max results reached. Refine your search by typing.
    </div>
    """
  end

  def select_option(js \\ %JS{}, id, submit_value, display_value) do
    js
    |> JS.dispatch("phx:notify-selection-change",
      detail: %{
        id: id,
        value: %{"submitValue" => submit_value, "displayValue" => display_value}
      }
    )
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

  def handle_event(
        "search",
        %{"_target" => [target]} = params,
        %{assigns: %{options: options}} = socket
      ) do
    input = params[target]

    input_len = input |> String.trim() |> String.length()

    socket =
      if socket.assigns[:creatable] do
        assign(socket, display_value: input, submit_value: input)
      else
        socket
      end

    suggestions =
      if input_len > 0 do
        run_suggest_fun(input, options, socket.assigns, :suggestions)
      else
        options
      end
      |> Enum.take(suggestions_limit(socket.assigns))

    {:noreply, assign(socket, %{suggestions: suggestions})}
  end

  defp do_select(socket, submit_value, display_value) do
    id = socket.assigns.id

    socket =
      socket
      |> push_event("update-value", %{id: id, value: display_value, fire: false})
      |> push_event("update-value", %{id: "submit-#{id}", value: submit_value, fire: true})
      |> assign(:display_value, display_value)
      |> assign(:submit_value, submit_value)

    if socket.assigns[:on_selection_made] do
      socket.assigns.on_selection_made.(submit_value, id)
    end

    socket
  end

  defp suggestions_limit(assigns) do
    Map.get(assigns, :suggestions_limit, @default_suggestions_limit)
  end

  defp display_creatable_option?(assigns) do
    empty_input? = String.length(assigns.display_value) == 0

    input_matches_suggestion? =
      Enum.any?(assigns.suggestions, fn {suggestion, _} -> assigns.display_value == suggestion end)

    assigns.creatable && not empty_input? && not input_matches_suggestion?
  end

  defp assign_options(socket) do
    assign_new(socket, :options, fn ->
      run_suggest_fun("", [], socket.assigns, :options)
    end)
  end

  defp assign_suggestions(socket) do
    if socket.assigns[:suggestions] do
      assign(
        socket,
        suggestions: Enum.take(socket.assigns.suggestions, suggestions_limit(socket.assigns))
      )
    else
      socket
    end
  end

  defp select_default(socket) do
    case {socket.assigns[:selected], socket.assigns[:submit_value]} do
      {{submit_value, display_value}, nil} ->
        assign(socket, submit_value: submit_value, display_value: display_value)

      {submit_and_display_value, nil} when is_binary(submit_and_display_value) ->
        assign(socket,
          submit_value: submit_and_display_value,
          display_value: submit_and_display_value
        )

      _ ->
        socket
    end
  end

  defp run_suggest_fun(input, options, %{id: id, suggest_fun: fun} = assigns, key_to_update) do
    if assigns[:async] do
      pid = self()

      Task.start(fn ->
        result = fun.(input, options)

        send_update(
          pid,
          __MODULE__,
          Keyword.new([
            {:id, id},
            {key_to_update, result}
          ])
        )
      end)

      # This prevents flashing the suggestions container
      # before the update is received on a subsequent render
      assigns[key_to_update] || []
    else
      fun.(input, options)
    end
  end
end
