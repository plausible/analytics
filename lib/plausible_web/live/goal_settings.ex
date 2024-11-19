defmodule PlausibleWeb.Live.GoalSettings do
  @moduledoc """
  LiveView allowing listing, creating and deleting goals.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Goals
  alias PlausibleWeb.Live.Components.Modal

  def mount(
        _params,
        %{"site_id" => site_id, "domain" => domain},
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        current_user
        |> Plausible.Teams.Adapter.Read.Sites.get_for_user!(domain, [:owner, :admin, :super_admin])
        |> Plausible.Imported.load_import_data()
      end)
      |> assign_new(:all_goals, fn %{site: site} ->
        Goals.for_site(site, preload_funnels?: true)
      end)
      |> assign_new(:event_name_options, fn %{site: site, all_goals: all_goals} ->
        exclude =
          all_goals
          |> Enum.reject(&is_nil(&1.event_name))
          |> Enum.map(& &1.event_name)

        Plausible.Stats.GoalSuggestions.suggest_event_names(site, "",
          exclude: exclude,
          limit: :unlimited
        )
      end)

    {:ok,
     assign(socket,
       site_id: site_id,
       domain: domain,
       displayed_goals: socket.assigns.all_goals,
       filter_text: "",
       form_goal: nil
     )}
  end

  # Flash sharing with live views within dead views can be done via re-rendering the flash partial.
  # Normally, we'd have to use live_patch which we can't do with views unmounted at the router it seems.
  def render(assigns) do
    ~H"""
    <div id="goal-settings-main">
      <.flash_messages flash={@flash} />

      <.live_component :let={modal_unique_id} module={Modal} id="goals-form-modal">
        <.live_component
          module={PlausibleWeb.Live.GoalSettings.Form}
          id={"goals-form-#{modal_unique_id}"}
          context_unique_id={modal_unique_id}
          event_name_options={@event_name_options}
          domain={@domain}
          site={@site}
          current_user={@current_user}
          existing_goals={@all_goals}
          goal={@form_goal}
          on_save_goal={
            fn goal, socket ->
              send(self(), {:goal_added, goal})
              Modal.close(socket, "goals-form-modal")
            end
          }
          on_autoconfigure={
            fn socket ->
              send(self(), :autoconfigure)
              Modal.close(socket, "goals-form-modal")
            end
          }
        />
      </.live_component>
      <.live_component
        module={PlausibleWeb.Live.GoalSettings.List}
        id="goals-list"
        goals={@displayed_goals}
        domain={@domain}
        filter_text={@filter_text}
        site={@site}
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

  def handle_event("edit-goal", %{"goal-id" => goal_id}, socket) do
    goal_id = String.to_integer(goal_id)
    form_goal = Plausible.Goals.get(socket.assigns.site, goal_id)

    socket = socket |> assign(form_goal: form_goal) |> Modal.open("goals-form-modal")
    {:noreply, socket}
  end

  def handle_event("add-goal", _, socket) do
    socket = socket |> assign(form_goal: nil) |> Modal.open("goals-form-modal")
    {:noreply, socket}
  end

  def handle_event("delete-goal", %{"goal-id" => goal_id} = params, socket) do
    goal_id = String.to_integer(goal_id)

    case Plausible.Goals.delete(goal_id, socket.assigns.site_id) do
      :ok ->
        event_name_options =
          if goal_name = params["goal-name"] do
            [goal_name | socket.assigns.event_name_options]
          else
            socket.assigns.event_name_options
          end

        socket =
          socket
          |> put_live_flash(:success, "Goal deleted successfully")
          |> assign(
            all_goals: Enum.reject(socket.assigns.all_goals, &(&1.id == goal_id)),
            event_name_options: event_name_options,
            displayed_goals: Enum.reject(socket.assigns.displayed_goals, &(&1.id == goal_id))
          )

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:goal_added, goal}, socket) do
    all_goals = Goals.for_site(socket.assigns.site, preload_funnels?: true)

    socket =
      socket
      |> assign(
        filter_text: "",
        all_goals: all_goals,
        event_name_options:
          Enum.reject(socket.assigns.event_name_options, &(&1 == goal.event_name)),
        displayed_goals: all_goals,
        form_goal: nil
      )
      |> put_live_flash(:success, "Goal saved successfully")

    {:noreply, socket}
  end

  def handle_info(:autoconfigure, socket) do
    %{event_name_options: names, site: site} = socket.assigns

    added_goals =
      names
      |> Plausible.Goals.batch_create_event_goals(site)
      |> Enum.map(&Map.put(&1, :funnels, []))

    socket =
      socket
      |> assign(
        filter_text: "",
        all_goals: added_goals ++ socket.assigns.all_goals,
        event_name_options: [],
        displayed_goals: added_goals ++ socket.assigns.all_goals
      )
      |> put_live_flash(:success, "All goals added successfully")

    {:noreply, socket}
  end
end
