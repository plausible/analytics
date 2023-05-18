defmodule PlausibleWeb.Live.FunnelSettings.Form do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def mount(socket) do
    {:ok, assign(socket, step_count: 2)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       form: assigns.form,
       goals: assigns.goals,
       site: assigns.site
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-4 gap-6 mt-6">
      <div class="col-span-4 sm:col-span-2">
        <.form
          :let={f}
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="save"
          onkeydown="return event.key != 'Enter';"
        >
          <%= label(f, "Funnel name",
            class: "block text-sm font-medium text-gray-700 dark:text-gray-300"
          ) %>
          <.input field={f[:name]} />

          <div :if={String.trim(f[:name].value) != ""} id="steps-builder">
            <%= label(f, "Funnel Steps",
              class: "mt-6 block text-sm font-medium text-gray-700 dark:text-gray-300"
            ) %>

            <.live_component
              :for={step_number <- 1..@step_count}
              submit_name="funnel[steps][][goal_id]"
              module={PlausibleWeb.Live.FunnelSettings.InputPicker}
              id={"step-#{step_number}"}
              options={Enum.map(@goals, fn goal -> {goal.id, Plausible.Goal.display_name(goal)} end)}
            />

            <a
              :if={@step_count < 5}
              class="underline text-indigo-600 text-sm cursor-pointer mt-6"
              phx-click="add-step"
              phx-target={@myself}
            >
              + Add another step
            </a>

            <div class="mt-6">
              <button type="submit" class="button mt-6">Save</button>
              <button
                type="button"
                class="inline-block mt-4 ml-2 px-4 py-2 border border-gray-300 dark:border-gray-500 text-sm leading-5 font-medium rounded-md text-red-700 bg-white dark:bg-gray-800 hover:text-red-500 dark:hover:text-red-400 focus:outline-none focus:border-blue-300 focus:ring active:text-red-800 active:bg-gray-50 transition ease-in-out duration-150 "
                phx-click="cancel_add_funnel"
              >
                Cancel
              </button>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr(:field, Phoenix.HTML.FormField)

  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@field.name}>
      <input
        autocomplete="off"
        autofocus
        type="text"
        id={@field.id}
        name={@field.name}
        value={@field.value}
        phx-debounce="300"
        class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-full rounded-md sm:text-sm border-gray-300 dark:border-gray-500"
      />

      <.error :for={{msg, _} <- @field.errors}>Funnel name <%= msg %></.error>
    </div>
    """
  end

  def error(assigns) do
    ~H"""
    <div class="mt-2 text-sm text-red-600">
      <%= render_slot(@inner_block) %>
    </div>
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

  def handle_event("validate", %{"funnel" => params}, socket) do
    changeset =
      Plausible.Funnels.create_changeset(
        socket.assigns.site,
        params["name"],
        params["steps"] || []
      )
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"funnel" => params}, %{assigns: %{site: site}} = socket) do
    IO.inspect(:saving)

    case Plausible.Funnels.create(site, params["name"], params["steps"]) do
      {:ok, funnel} ->
        send(self(), {:funnel_saved, funnel})
        {:noreply, socket}

      {:error, changeset} ->
        IO.inspect(changeset)

        IO.inspect(to_form(changeset))

        Ecto.Changeset.traverse_errors(changeset, fn thing ->
          IO.inspect(thing)
        end)

        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
