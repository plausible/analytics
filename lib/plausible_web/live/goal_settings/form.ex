defmodule PlausibleWeb.Live.GoalSettings.Form do
  @moduledoc """
  Live view for the goal creation form
  """
  use PlausibleWeb, :live_component
  use Plausible

  alias PlausibleWeb.Live.Components.ComboBox
  alias Plausible.Repo

  def update(assigns, socket) do
    site = Repo.preload(assigns.site, [:team, :owner])

    has_access_to_revenue_goals? =
      Plausible.Billing.Feature.RevenueGoals.check_availability(site.team) == :ok

    form =
      (assigns.goal || %Plausible.Goal{})
      |> Plausible.Goal.changeset()
      |> to_form()

    selected_tab =
      case assigns.goal do
        %{page_path: p, scroll_threshold: s} when not is_nil(p) and s > -1 -> "scroll"
        %{page_path: p} when not is_nil(p) -> "pageviews"
        _goal_or_nil -> "custom_events"
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
        site_team: assigns.site_team,
        domain: assigns.domain,
        selected_tab: selected_tab,
        tab_sequence_id: 0,
        site: site,
        has_access_to_revenue_goals?: has_access_to_revenue_goals?,
        existing_goals: assigns.existing_goals,
        on_save_goal: assigns.on_save_goal,
        on_autoconfigure: assigns.on_autoconfigure,
        goal: assigns.goal
      )

    {:ok, socket}
  end

  # Regular functions instead of component calls are used here
  # explicitly to avoid breaking change tracking. Done following
  # advice from https://hexdocs.pm/phoenix_live_view/assigns-eex.html#the-assigns-variable.
  def render(assigns) do
    ~H"""
    <div id={@id}>
      {if @goal, do: edit_form(assigns)}
      {if is_nil(@goal), do: create_form(assigns)}
    </div>
    """
  end

  def edit_form(assigns) do
    ~H"""
    <.form :let={f} for={@form} phx-submit="save-goal" phx-target={@myself}>
      <.title>Edit Goal for {@domain}</.title>

      <.custom_event_fields
        :if={@selected_tab == "custom_events"}
        f={f}
        suffix={@context_unique_id}
        current_user={@current_user}
        site_team={@site_team}
        site={@site}
        goal={@goal}
        existing_goals={@existing_goals}
        goal_options={@event_name_options}
        has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
      />
      <.pageview_fields
        :if={@selected_tab == "pageviews"}
        f={f}
        goal={@goal}
        suffix={@context_unique_id}
        site={@site}
      />
      <.scroll_fields
        :if={@selected_tab == "scroll"}
        f={f}
        goal={@goal}
        suffix={@context_unique_id}
        site={@site}
      />

      <.button type="submit" class="w-full">
        Update Goal
      </.button>
    </.form>
    """
  end

  def create_form(assigns) do
    ~H"""
    <.form
      :let={f}
      x-data="{ tabSelectionInProgress: false }"
      for={@form}
      phx-submit="save-goal"
      phx-target={@myself}
    >
      <.spinner class="spinner block absolute right-9 top-8" x-show="tabSelectionInProgress" />

      <.title>Add Goal for {@domain}</.title>

      <.tabs current_user={@current_user} site={@site} selected_tab={@selected_tab} myself={@myself} />

      <.custom_event_fields
        :if={@selected_tab == "custom_events"}
        x-show="!tabSelectionInProgress"
        f={f}
        suffix={suffix(@context_unique_id, @tab_sequence_id)}
        current_user={@current_user}
        site_team={@site_team}
        site={@site}
        existing_goals={@existing_goals}
        goal_options={@event_name_options}
        has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
        x-init="tabSelectionInProgress = false"
      />
      <.pageview_fields
        :if={@selected_tab == "pageviews"}
        x-show="!tabSelectionInProgress"
        f={f}
        suffix={suffix(@context_unique_id, @tab_sequence_id)}
        site={@site}
        x-init="tabSelectionInProgress = false"
      />
      <.scroll_fields
        :if={@selected_tab == "scroll"}
        x-show="!tabSelectionInProgress"
        f={f}
        suffix={suffix(@context_unique_id, @tab_sequence_id)}
        site={@site}
        x-init="tabSelectionInProgress = false"
      />

      <div x-show="!tabSelectionInProgress">
        <.button type="submit" class="w-full">
          Add Goal
        </.button>
      </div>

      <button
        :if={@selected_tab == "custom_events" && @event_name_options_count > 0}
        x-show="!tabSelectionInProgress"
        class="mt-4 text-sm hover:underline text-indigo-600 dark:text-indigo-400 text-left"
        phx-click="autoconfigure"
        phx-target={@myself}
      >
        <span :if={@event_name_options_count > 1}>
          Already sending custom events? We've found {@event_name_options_count} custom events from the last 6 months that are not yet configured as goals. Click here to add them.
        </span>
        <span :if={@event_name_options_count == 1}>
          Already sending custom events? We've found 1 custom event from the last 6 months that is not yet configured as a goal. Click here to add it.
        </span>
      </button>
    </.form>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)
  attr(:suffix, :string)
  attr(:goal, Plausible.Goal, default: nil)
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
        x-on-selection-change="document.getElementById('pageview_display_name_input').setAttribute('value', 'Visit ' + $event.detail.value.displayValue)"
      />

      <.error :for={msg <- Enum.map(@f[:page_path].errors, &translate_error/1)}>
        {msg}
      </.error>

      <.input
        label="Display Name"
        id="pageview_display_name_input"
        field={@f[:display_name]}
        type="text"
        x-data="{ firstFocus: true }"
        x-on:focus="if (firstFocus) { $el.select(); firstFocus = false; }"
      />
    </div>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)
  attr(:suffix, :string)
  attr(:goal, Plausible.Goal, default: nil)
  attr(:rest, :global)

  def scroll_fields(assigns) do
    js =
      if is_nil(assigns.goal) do
        """
        {
          scrollThreshold: '90',
          pagePath: '',
          displayName: '',
          updateDisplayName() {
            if (this.scrollThreshold && this.pagePath) {
              this.displayName = `Scroll ${this.scrollThreshold}% on ${this.pagePath}`
            }
          }
        }
        """
      else
        """
        {
          scrollThreshold: '#{assigns.goal.scroll_threshold}',
          pagePath: '#{assigns.goal.page_path}',
          displayName: '#{assigns.goal.display_name}',
          updateDisplayName() {}
        }
        """
      end

    assigns = assign(assigns, :js, js)

    ~H"""
    <div id="scroll-form" class="py-2" x-data={@js} {@rest}>
      <.label for={"scroll_threshold_input_#{@suffix}"}>
        Scroll Percentage Threshold (0-100)
      </.label>

      <.input
        id={"scroll_threshold_input_#{@suffix}"}
        required
        field={@f[:scroll_threshold]}
        type="number"
        min="0"
        max="100"
        step="1"
        x-model="scrollThreshold"
        x-on:change="updateDisplayName"
      />

      <.label for={"scroll_page_path_input_#{@suffix}"} class="mt-3">
        Page Path
      </.label>

      <.live_component
        id={"scroll_page_path_input_#{@suffix}"}
        submit_name="goal[page_path]"
        class={[
          "py-2"
        ]}
        module={ComboBox}
        suggest_fun={fn input, _options -> suggest_page_paths(input, @site) end}
        selected={if @goal && @goal.page_path, do: @goal.page_path}
        creatable
        x-on-selection-change="pagePath = $event.detail.value.displayValue; updateDisplayName()"
      />

      <.error :for={msg <- Enum.map(@f[:page_path].errors, &translate_error/1)}>
        {msg}
      </.error>

      <.input
        label="Display Name"
        id="scroll_display_name_input"
        field={@f[:display_name]}
        type="text"
        x-model="displayName"
      />
    </div>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)
  attr(:current_user, Plausible.Auth.User)
  attr(:site_team, Plausible.Teams.Team)
  attr(:suffix, :string)
  attr(:existing_goals, :list)
  attr(:goal_options, :list)
  attr(:goal, Plausible.Goal, default: nil)
  attr(:has_access_to_revenue_goals?, :boolean)

  attr(:rest, :global)

  def custom_event_fields(assigns) do
    ~H"""
    <div id="custom-events-form" class="my-6" {@rest}>
      <div id="event-fields">
        <div class="text-sm pb-6 text-gray-500 dark:text-gray-400 text-justify rounded-md">
          Custom Events are not tracked by default - you have to configure them on your site to be sent to Plausible. See examples and learn more in
          <.styled_link href="https://plausible.io/docs/custom-event-goals" new_tab={true}>
            our docs
          </.styled_link>.
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
            {msg}
          </.error>
        </div>

        <div class="mt-2">
          <.input
            label="Display Name"
            id="custom_event_display_name_input"
            field={@f[:display_name]}
            type="text"
            x-data="{ firstFocus: true }"
            x-on:focus="if (firstFocus) { $el.select(); firstFocus = false; }"
          />
        </div>

        <.revenue_goal_settings
          :if={ee?()}
          f={@f}
          site={@site}
          current_user={@current_user}
          site_team={@site_team}
          has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
          goal={@goal}
          suffix={@suffix}
        />
      </div>
    </div>
    """
  end

  def revenue_goal_settings(assigns) do
    js_data =
      Jason.encode!(%{
        active: !!assigns.f[:currency].value and assigns.f[:currency].value != "",
        currency: assigns.f[:currency].value
      })

    assigns = assign(assigns, selected_currency: currency_option(assigns.goal), js_data: js_data)

    ~H"""
    <div class="mt-6 space-y-3" x-data={@js_data}>
      <PlausibleWeb.Components.Billing.Notice.premium_feature
        billable_user={@site.owner}
        current_user={@current_user}
        current_team={@site_team}
        feature_mod={Plausible.Billing.Feature.RevenueGoals}
        class="rounded-b-md"
      />
      <button
        id={"currency-toggle-#{@suffix}"}
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
        disabled={not @has_access_to_revenue_goals? or not is_nil(@goal)}
      >
        <span
          id={"currency-container1-#{@suffix}"}
          class="relative inline-flex h-6 w-11 flex-shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2"
          x-bind:class="active ? 'bg-indigo-600' : 'dark:bg-gray-700 bg-gray-200'"
        >
          <span
            id={"currency-container2-#{@suffix}"}
            aria-hidden="true"
            class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
            x-bind:class="active ? 'dark:bg-gray-800 translate-x-5' : 'dark:bg-gray-800 translate-x-0'"
          />
        </span>
        <span
          class={[
            "ml-3 text-sm font-medium",
            if(@has_access_to_revenue_goals?,
              do: "text-gray-900  dark:text-gray-100",
              else: "text-gray-500 dark:text-gray-400"
            )
          ]}
          id="enable-revenue-tracking"
        >
          Enable Revenue Tracking
        </span>
      </button>

      <div x-show="active" id={"revenue-input-#{@suffix}"}>
        <.live_component
          id={"currency_input_#{@suffix}"}
          submit_name={@f[:currency].name}
          module={ComboBox}
          selected={@selected_currency}
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
    """
  end

  def tabs(assigns) do
    ~H"""
    <div class="text-sm mt-6 font-medium dark:text-gray-100">Goal Trigger</div>
    <div class="my-2 text-sm w-full flex rounded border border-gray-300 dark:border-gray-500 overflow-hidden">
      <.custom_events_tab selected?={@selected_tab == "custom_events"} myself={@myself} />
      <.pageviews_tab selected?={@selected_tab == "pageviews"} myself={@myself} />
      <.scroll_tab
        :if={Plausible.Stats.ScrollDepth.feature_visible?(@site, @current_user)}
        selected?={@selected_tab == "scroll"}
        myself={@myself}
      />
    </div>
    """
  end

  defp custom_events_tab(assigns) do
    ~H"""
    <a
      class={[
        "flex-1 text-center py-2.5 border-r dark:border-gray-500",
        "cursor-pointer",
        @selected? && "shadow-inner font-medium bg-indigo-600 text-white",
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
        "flex-1 text-center py-2.5 cursor-pointer",
        @selected? && "shadow-inner font-medium bg-indigo-600 text-white",
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

  def scroll_tab(assigns) do
    ~H"""
    <a
      class={[
        "flex-1 text-center py-2.5 cursor-pointer border-l dark:border-gray-500",
        @selected? && "shadow-inner font-medium bg-indigo-600 text-white",
        !@selected? && "dark:text-gray-100 text-gray-800"
      ]}
      id="scroll-tab"
      x-on:click={!@selected? && "tabSelectionInProgress = true"}
      phx-click="switch-tab"
      phx-value-tab="scroll"
      phx-target={@myself}
    >
      Scroll
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
    defp currency_option(nil), do: nil

    defp currency_option(goal) do
      Plausible.Goal.Revenue.revenue?(goal) &&
        Plausible.Goal.Revenue.currency_option(goal.currency)
    end
  else
    defp currency_option(_), do: nil
  end
end
