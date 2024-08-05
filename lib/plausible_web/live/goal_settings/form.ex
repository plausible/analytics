defmodule PlausibleWeb.Live.GoalSettings.Form do
  @moduledoc """
  Live view for the goal creation form
  """
  use Phoenix.LiveComponent, global_prefixes: ~w(x-)
  use Plausible

  import PlausibleWeb.Live.Components.Form

  alias PlausibleWeb.Live.Components.ComboBox
  alias Plausible.Repo

  def update(assigns, socket) do
    site = Repo.preload(assigns.site, [:owner])
    owner = Plausible.Users.with_subscription(site.owner)
    site = %{site | owner: owner}

    has_access_to_revenue_goals? =
      Plausible.Billing.Feature.RevenueGoals.check_availability(owner) == :ok

    goal_id = if assigns.goal_id, do: String.to_integer(assigns.goal_id)
    goal = goal_id && Plausible.Goals.get(site, goal_id)

    form =
      (goal || %Plausible.Goal{})
      |> Plausible.Goal.changeset()
      |> to_form()

    selected_tab =
      if goal && goal.page_path do
        "pageviews"
      else
        "custom_events"
      end

    socket =
      socket
      |> assign(
        id: assigns.id,
        context_unique_id: assigns.context_unique_id,
        form: form,
        event_name_options_count: length(assigns.event_name_options),
        event_name_options: Enum.map(assigns.event_name_options, &{&1, &1}),
        current_user: assigns.current_user,
        domain: assigns.domain,
        selected_tab: selected_tab,
        tab_sequence_id: 0,
        site: site,
        has_access_to_revenue_goals?: has_access_to_revenue_goals?,
        existing_goals: assigns.existing_goals,
        on_save_goal: assigns.on_save_goal,
        on_autoconfigure: assigns.on_autoconfigure,
        goal_id: goal_id,
        goal: goal_id && goal
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.form
        :let={f}
        x-data="{ tabSelectionInProgress: false }"
        for={@form}
        phx-submit="save-goal"
        phx-target={@myself}
      >
        <PlausibleWeb.Components.Generic.spinner
          class="spinner block absolute right-9 top-8"
          x-show="tabSelectionInProgress"
        />

        <h2 class="text-xl font-black dark:text-gray-100">
          <%= if @goal, do: "Edit", else: "Add" %> Goal for <%= @domain %>
        </h2>

        <.tabs goal={@goal} selected_tab={@selected_tab} myself={@myself} />

        <.custom_event_fields
          :if={@selected_tab == "custom_events"}
          x-show="!tabSelectionInProgress"
          f={f}
          suffix={suffix(@context_unique_id, @tab_sequence_id)}
          current_user={@current_user}
          site={@site}
          goal={@goal}
          existing_goals={@existing_goals}
          goal_options={@event_name_options}
          has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
          x-init="tabSelectionInProgress = false"
        />
        <.pageview_fields
          :if={@selected_tab == "pageviews"}
          x-show="!tabSelectionInProgress"
          f={f}
          goal={@goal}
          suffix={suffix(@context_unique_id, @tab_sequence_id)}
          site={@site}
          x-init="tabSelectionInProgress = false"
        />

        <div class="py-4" x-show="!tabSelectionInProgress">
          <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
            <%= if @goal, do: "Update", else: "Add" %> Goal →
          </PlausibleWeb.Components.Generic.button>
        </div>

        <button
          :if={@selected_tab == "custom_events" && @event_name_options_count > 0 && is_nil(@goal)}
          x-show="!tabSelectionInProgress"
          class="mt-2 text-sm hover:underline text-indigo-600 dark:text-indigo-400 text-left"
          phx-click="autoconfigure"
          phx-target={@myself}
        >
          <span :if={@event_name_options_count > 1}>
            Already sending custom events? We've found <%= @event_name_options_count %> custom events from the last 6 months that are not yet configured as goals. Click here to add them.
          </span>
          <span :if={@event_name_options_count == 1}>
            Already sending custom events? We've found 1 custom event from the last 6 months that is not yet configured as a goal. Click here to add it.
          </span>
        </button>
      </.form>
    </div>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)
  attr(:suffix, :string)
  attr(:goal, Plausible.Goal)
  attr(:rest, :global)

  def pageview_fields(assigns) do
    ~H"""
    <div id="pageviews-form" class="py-2" {@rest}>
      <.label for={"page_path_input_#{@suffix}"}>
        Page Path
      </.label>

      <.live_component
        id={"page_path_input_#{@suffix}"}
        submit_name="goal[page_path]"
        class={[
          "py-2"
        ]}
        module={ComboBox}
        suggest_fun={fn input, _options -> suggest_page_paths(input, @site) end}
        selected={if @goal && @goal.page_path, do: @goal.page_path}
        creatable
        x-on-selection-change="document.getElementById('display_name_input').setAttribute('value', 'Visit ' + $event.detail.value.displayValue)"
      />

      <.error :for={msg <- Enum.map(@f[:page_path].errors, &translate_error/1)}>
        <%= msg %>
      </.error>

      <div class="mt-2">
        <.label for={"display_name_input_#{@suffix}"}>
          Display Name
        </.label>

        <.input
          id="display_name_input"
          field={@f[:display_name]}
          type="text"
          x-data="{ firstFocus: true }"
          x-on:focus="if (firstFocus) { $el.select(); firstFocus = false; }"
          class="mt-2 dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
        />
      </div>
    </div>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)
  attr(:current_user, Plausible.Auth.User)
  attr(:suffix, :string)
  attr(:existing_goals, :list)
  attr(:goal_options, :list)
  attr(:goal, Plausible.Goal)
  attr(:has_access_to_revenue_goals?, :boolean)

  attr(:rest, :global)

  def custom_event_fields(assigns) do
    ~H"""
    <div id="custom-events-form" class="my-6" {@rest}>
      <div id="event-fields">
        <div class="pb-6 text-xs text-gray-700 dark:text-gray-200 text-justify rounded-md">
          Custom Events are not tracked by default - you have to configure them on your site to be sent to Plausible. See examples and learn more in <a
            class="text-indigo-500 hover:underline"
            target="_blank"
            rel="noreferrer"
            href="https://plausible.io/docs/custom-event-goals"
          > our docs</a>.
        </div>

        <div>
          <.label for={"event_name_input_#{@suffix}"}>
            Event Name
          </.label>

          <.live_component
            id={"event_name_input_#{@suffix}"}
            submit_name="goal[event_name]"
            placeholder="e.g. Signup"
            class={[
              "py-2"
            ]}
            module={ComboBox}
            suggest_fun={fn input, _options -> suggest_event_names(input, @site, @existing_goals) end}
            options={@goal_options}
            selected={if @goal && @goal.event_name, do: @goal.event_name}
            creatable
            x-on-selection-change="document.getElementById('custom_event_display_name_input').setAttribute('value', $event.detail.value.displayValue)"
          />

          <.error :for={msg <- Enum.map(@f[:event_name].errors, &translate_error/1)}>
            <%= msg %>
          </.error>
        </div>

        <div class="mt-2">
          <.label for={"custom_event_display_name_input_#{@suffix}"}>
            Display Name
          </.label>

          <.input
            id="custom_event_display_name_input"
            field={@f[:display_name]}
            type="text"
            x-data="{ firstFocus: true }"
            x-on:focus="if (firstFocus) { $el.select(); firstFocus = false; }"
            class="mt-2 dark:bg-gray-900 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:text-gray-300"
          />
        </div>

        <div
          :if={ee?()}
          class="mt-6 space-y-3"
          x-data={
            Jason.encode!(%{
              active: !!@f[:currency].value and @f[:currency].value != "",
              currency: @f[:currency].value
            })
          }
        >
          <PlausibleWeb.Components.Billing.Notice.premium_feature
            billable_user={@site.owner}
            current_user={@current_user}
            feature_mod={Plausible.Billing.Feature.RevenueGoals}
            size={:xs}
            class="rounded-b-md"
          />
          <button
            class={[
              "flex items-center w-max mb-3",
              if @has_access_to_revenue_goals? and is_nil(@goal) do
                "cursor-pointer"
              else
                "cursor-not-allowed"
              end
            ]}
            aria-labelledby="enable-revenue-tracking"
            role="switch"
            type="button"
            x-on:click="active = !active; currency = ''"
            x-bind:aria-checked="active"
            disabled={(not @has_access_to_revenue_goals? or not is_nil(@goal)) && "disabled"}
          >
            <span
              id={"currency-switcher-1-#{:erlang.phash2(@f)}"}
              class="relative inline-flex h-6 w-11 flex-shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2"
              x-bind:class="active ? 'bg-indigo-600' : 'dark:bg-gray-700 bg-gray-200'"
            >
              <span
                id={"currency-switcher-2-#{:erlang.phash2(@f)}"}
                aria-hidden="true"
                class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
                x-bind:class="active ? 'dark:bg-gray-800 translate-x-5' : 'dark:bg-gray-800 translate-x-0'"
              />
            </span>
            <span
              class={[
                "ml-3 font-medium",
                if(assigns.has_access_to_revenue_goals?,
                  do: "text-gray-900  dark:text-gray-100",
                  else: "text-gray-500 dark:text-gray-300"
                )
              ]}
              id={"enable-revenue-tracking-#{:erlang.phash2(@f)}"}
            >
              Enable Revenue Tracking
            </span>
          </button>

          <div x-show="active" id={"revenue-input-#{:erlang.phash2(@f)}"}>
            <.live_component
              id={"currency_input_#{@suffix}"}
              submit_name={@f[:currency].name}
              module={ComboBox}
              selected={if revenue?(@goal), do: currency_option(@goal)}
              suggest_fun={
                on_ee do
                  fn
                    "", [] ->
                      Plausible.Goal.Revenue.currency_options()

                    input, options ->
                      ComboBox.StaticSearch.suggest(input, options, weight_threshold: 0.8)
                  end
                end
              }
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def tabs(assigns) do
    ~H"""
    <%= if is_nil(@goal) do %>
      <div class="mt-6 font-medium dark:text-gray-100">Goal Trigger</div>
      <div class="my-3 w-full flex rounded border border-gray-300 dark:border-gray-500">
        <.custom_events_tab selected?={@selected_tab == "custom_events"} myself={@myself} />
        <.pageviews_tab selected?={@selected_tab == "pageviews"} myself={@myself} />
      </div>
    <% end %>
    """
  end

  defp custom_events_tab(assigns) do
    ~H"""
    <a
      class={[
        "w-1/2 text-center py-2 border-r dark:border-gray-500",
        "cursor-pointer",
        @selected? && "shadow-inner font-bold bg-indigo-600 text-white",
        !@selected? && "dark:text-gray-100 text-gray-800"
      ]}
      id="event-tab"
      x-on:click={!@selected? && "tabSelectionInProgress = true"}
      phx-click="switch-tab"
      phx-value-tab="custom_events"
      phx-target={@myself}
    >
      Custom Event
    </a>
    """
  end

  def pageviews_tab(assigns) do
    ~H"""
    <a
      class={[
        "w-1/2 text-center py-2 cursor-pointer",
        @selected? && "shadow-inner font-bold bg-indigo-600 text-white",
        !@selected? && "dark:text-gray-100 text-gray-800"
      ]}
      id="pageview-tab"
      x-on:click={!@selected? && "tabSelectionInProgress = true"}
      phx-click="switch-tab"
      phx-value-tab="pageviews"
      phx-target={@myself}
    >
      Pageview
    </a>
    """
  end

  def handle_event("switch-tab", %{"tab" => tab}, socket) do
    socket =
      socket
      |> assign(:selected_tab, tab)
      |> update(:tab_sequence_id, &(&1 + 1))

    {:noreply, socket}
  end

  def handle_event("save-goal", %{"goal" => goal_params}, %{assigns: %{goal: nil}} = socket) do
    case Plausible.Goals.create(socket.assigns.site, goal_params) do
      {:ok, goal} ->
        socket =
          goal
          |> Map.put(:funnels, [])
          |> socket.assigns.on_save_goal.(socket)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event(
        "save-goal",
        %{"goal" => goal_params},
        %{assigns: %{goal: %Plausible.Goal{} = goal}} = socket
      ) do
    case Plausible.Goals.update(goal, goal_params) do
      {:ok, goal} ->
        socket = socket.assigns.on_save_goal.(goal, socket)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("autoconfigure", _params, socket) do
    {:noreply, socket.assigns.on_autoconfigure.(socket)}
  end

  def suggest_page_paths(input, site) do
    query = Plausible.Stats.Query.from(site, %{"with_imported" => "true", "period" => "all"})

    site
    |> Plausible.Stats.filter_suggestions(query, "page", input)
    |> Enum.map(fn %{label: label, value: value} -> {label, value} end)
  end

  def suggest_event_names(input, site, existing_goals) do
    existing_names =
      existing_goals
      |> Enum.reject(&is_nil(&1.event_name))
      |> Enum.map(& &1.event_name)

    site
    |> Plausible.Stats.GoalSuggestions.suggest_event_names(input, exclude: existing_names)
    |> Enum.map(fn name -> {name, name} end)
  end

  defp suffix(context_unique_id, tab_sequence_id) do
    "#{context_unique_id}-tabseq#{tab_sequence_id}"
  end

  on_ee do
    defp revenue?(goal) do
      goal && Plausible.Goal.Revenue.revenue?(goal)
    end

    defp currency_option(goal) do
      Plausible.Goal.Revenue.currency_option(goal.currency)
    end
  else
    defp revenue?(_), do: false
    defp currency_option(_), do: nil
  end
end
