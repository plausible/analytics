defmodule PlausibleWeb.Live.FunnelSettings.Form do
  @moduledoc """
  Phoenix LiveComponent that renders a form used for setting up funnels.
  Makes use of dynamically placed `PlausibleWeb.Live.FunnelSettings.ComboBox` components
  to allow building searchable funnel definitions out of list of goals available.
  """

  use Phoenix.LiveView
  use Phoenix.HTML
  use Plausible.Funnel

  alias Plausible.{Sites, Goals}

  def mount(_params, %{"current_user_id" => user_id, "domain" => domain}, socket) do
    site = Sites.get_for_user!(user_id, domain, [:owner, :admin, :super_admin])

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

    {:ok,
     assign(socket,
       step_ids: Enum.to_list(1..Funnel.min_steps()),
       form: to_form(Plausible.Funnels.create_changeset(site, "", [])),
       goals: goals,
       site: site,
       selections_made: Map.new(),
       evaluation_result: nil,
       evaluation_at: System.monotonic_time()
     )}
  end

  def render(assigns) do
    ~H"""
    <div id="funnel-form" class="grid grid-cols-2 gap-6 mt-6">
      <div class="col-span-2 sm:col-span-2">
        <.form
          :let={f}
          for={@form}
          phx-change="validate"
          phx-submit="save"
          phx-target="#funnel-form"
          onkeydown="return event.key != 'Enter';"
        >
          <%= label(f, "Funnel name",
            class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
          ) %>
          <.input field={f[:name]} />

          <div id="steps-builder">
            <%= label(f, "Funnel Steps",
              class: "mt-6 block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
            ) %>

            <div :for={step_idx <- @step_ids} class="flex mb-3">
              <div class="w-2/5 flex-1">
                <.live_component
                  submit_name="funnel[steps][][goal_id]"
                  module={PlausibleWeb.Live.Components.ComboBox}
                  suggest_fun={&PlausibleWeb.Live.Components.ComboBox.StaticSearch.suggest/2}
                  id={"step-#{step_idx}"}
                  options={reject_alrady_selected("step-#{step_idx}", @goals, @selections_made)}
                />
              </div>

              <div class="w-min inline-flex items-center align-middle">
                <.remove_step_button :if={length(@step_ids) > Funnel.min_steps()} step_idx={step_idx} />
              </div>

              <div class="w-2/5 inline-flex items-center ml-2 mb-3 text-gray-500 dark:text-gray-400">
                <.evaluation
                  :if={@evaluation_result}
                  result={@evaluation_result}
                  at={Enum.find_index(@step_ids, &(&1 == step_idx))}
                />
              </div>
            </div>

            <.add_step_button :if={
              length(@step_ids) < Funnel.max_steps() and
                map_size(@selections_made) < length(@goals)
            } />

            <div class="mt-6">
              <p id="funnel-eval" class="text-gray-500 dark:text-gray-400 text-sm mt-2 mb-2">
                <%= if @evaluation_result do %>
                  Last month conversion rate: <strong><%= List.last(@evaluation_result.steps).conversion_rate %></strong>%
                <% else %>
                  <span class="text-red-600 text-sm">
                    Choose minimum <%= Funnel.min_steps() %> steps to evaluate funnel.
                  </span>
                <% end %>
              </p>
            </div>

            <div class="mt-6">
              <%= if has_steps_errors?(f) or map_size(@selections_made) < Funnel.min_steps() or length(@step_ids) > map_size(@selections_made) do %>
                <.submit_button_inactive />
              <% else %>
                <.submit_button />
              <% end %>
              <.cancel_button />
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
        class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500"
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

  attr(:step_idx, :integer, required: true)

  def remove_step_button(assigns) do
    ~H"""
    <div class="inline-flex items-center ml-2 mb-4 text-red-600">
      <svg
        id={"remove-step-#{@step_idx}"}
        class="feather feather-sm cursor-pointer"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        phx-click="remove-step"
        phx-value-step-idx={@step_idx}
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

  def add_step_button(assigns) do
    ~H"""
    <a class="underline text-indigo-500 text-sm cursor-pointer mt-6" phx-click="add-step">
      + Add another step
    </a>
    """
  end

  def submit_button(assigns) do
    ~H"""
    <button id="save" type="submit" class="button mt-6">Save</button>
    """
  end

  def submit_button_inactive(assigns) do
    ~H"""
    <button
      type="none"
      id="save"
      class="inline-block mt-6 px-4 py-2 border border-gray-300 dark:border-gray-500 text-sm leading-5 font-medium rounded-md text-gray-300 bg-white dark:bg-gray-800 hover:text-gray-500 dark:hover:text-gray-400 focus:outline-none focus:border-blue-300 focus:ring active:text-gray-800 active:bg-gray-50 transition ease-in-out duration-150 cursor-not-allowed"
    >
      Save
    </button>
    """
  end

  def cancel_button(assigns) do
    ~H"""
    <button
      type="button"
      id="cancel"
      class="inline-block mt-4 ml-2 px-4 py-2 border border-gray-300 dark:border-gray-500 text-sm leading-5 font-medium rounded-md text-red-700 bg-white dark:bg-gray-800 hover:text-red-500 dark:hover:text-red-400 focus:outline-none focus:border-blue-300 focus:ring active:text-red-800 active:bg-gray-50 transition ease-in-out duration-150 "
      phx-click="cancel-add-funnel"
      phx-target="#funnel-settings-main"
    >
      Cancel
    </button>
    """
  end

  attr(:at, :integer, required: true)
  attr(:result, :map, required: true)

  def evaluation(assigns) do
    ~H"""
    <span class="text-xs" id={"step-eval-#{@at}"}>
      <% step = Enum.at(@result.steps, @at) %>
      <span :if={step && @at == 0}>
        <span
          class="border-dotted border-b border-gray-400 "
          tooltip="Sample calculation for last month"
        >
          Entering Visitors: <strong><%= @result.entering_visitors %></strong>
        </span>
      </span>
      <span :if={step && @at > 0}>
        Dropoff: <strong><%= Map.get(step, :dropoff_percentage) %>%</strong>
      </span>
    </span>
    """
  end

  def handle_event("add-step", _value, socket) do
    step_ids = socket.assigns.step_ids

    if length(step_ids) < Funnel.max_steps() do
      first_free_idx = find_sequence_break(step_ids)
      new_ids = step_ids ++ [first_free_idx]
      {:noreply, assign(socket, step_ids: new_ids)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove-step", %{"step-idx" => idx}, socket) do
    idx = String.to_integer(idx)
    step_ids = List.delete(socket.assigns.step_ids, idx)
    selections_made = drop_selection(socket.assigns.selections_made, idx)
    send(self(), :evaluate_funnel)

    {:noreply, assign(socket, step_ids: step_ids, selections_made: selections_made)}
  end

  def handle_event("validate", %{"funnel" => params}, socket) do
    changeset =
      socket.assigns.site
      |> Plausible.Funnels.create_changeset(
        params["name"],
        params["steps"] || []
      )
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"funnel" => params}, %{assigns: %{site: site}} = socket) do
    case Plausible.Funnels.create(site, params["name"], params["steps"]) do
      {:ok, funnel} ->
        send(
          socket.parent_pid,
          {:funnel_saved, Map.put(funnel, :steps_count, length(params["steps"]))}
        )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end

  def handle_info({:selection_made, %{submit_value: goal_id, by: combo_box}}, socket) do
    selections_made = store_selection(socket.assigns, combo_box, goal_id)

    send(self(), :evaluate_funnel)

    {:noreply,
     assign(socket,
       selections_made: selections_made
     )}
  end

  def handle_info(:evaluate_funnel, socket) do
    {:noreply, evaluate_funnel(socket)}
  end

  defp evaluate_funnel(%{assigns: %{selections_made: selections_made}} = socket)
       when map_size(selections_made) < Funnel.min_steps() do
    socket
  end

  defp evaluate_funnel(
         %{
           assigns: %{
             site: site,
             selections_made: selections_made,
             evaluation_at: evaluation_at
           }
         } = socket
       ) do
    with true <- seconds_since_evaluation(evaluation_at) >= 1,
         {:ok, {definition, query}} <- build_ephemeral_funnel(site, selections_made),
         {:ok, funnel} <- Plausible.Stats.funnel(site, query, definition) do
      assign(socket, evaluation_result: funnel, evaluation_at: System.monotonic_time())
    else
      _ ->
        socket
    end
  end

  defp seconds_since_evaluation(evaluation_at) do
    System.convert_time_unit(System.monotonic_time() - evaluation_at, :native, :second)
  end

  defp build_ephemeral_funnel(site, selections_made) do
    steps =
      selections_made
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {_, goal} ->
        %{
          "goal_id" => goal.id,
          "goal" => %{
            "id" => goal.id,
            "event_name" => goal.event_name,
            "page_path" => goal.page_path
          }
        }
      end)

    definition =
      Plausible.Funnels.ephemeral_definition(
        site,
        "Test funnel",
        steps
      )

    query = Plausible.Stats.Query.from(site, %{"period" => "all"})
    {:ok, {definition, query}}
  end

  defp find_sequence_break(input) do
    input
    |> Enum.sort()
    |> Enum.with_index(1)
    |> Enum.reduce_while(nil, fn {x, order}, _ ->
      if x != order do
        {:halt, order}
      else
        {:cont, order + 1}
      end
    end)
  end

  defp has_steps_errors?(f) do
    not f.source.valid?
  end

  defp get_goal(assigns, id) do
    assigns
    |> Map.fetch!(:goals)
    |> Enum.find_value(fn
      {goal_id, goal} when goal_id == id -> goal
      _ -> nil
    end)
  end

  defp store_selection(assigns, combo_box, goal_id) do
    Map.put(assigns.selections_made, combo_box, get_goal(assigns, goal_id))
  end

  defp drop_selection(selections_made, step_idx) do
    step_input_id = "step-#{step_idx}"
    Map.delete(selections_made, step_input_id)
  end

  defp reject_alrady_selected(combo_box, goals, selections_made) do
    selection_ids =
      Enum.map(selections_made, fn
        {_, %{id: goal_id}} -> goal_id
      end)

    result = Enum.reject(goals, fn {goal_id, _} -> goal_id in selection_ids end)

    send_update(PlausibleWeb.Live.Components.ComboBox, id: combo_box, suggestions: result)
    result
  end
end
