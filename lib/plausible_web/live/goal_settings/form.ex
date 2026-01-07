defmodule PlausibleWeb.Live.GoalSettings.Form do
  @moduledoc """
  Live view for the goal creation form
  """
  use PlausibleWeb, :live_component
  use Plausible

  alias PlausibleWeb.Live.Components.ComboBox
  alias Plausible.Repo
  alias Plausible.Stats.QueryBuilder

  def update(assigns, socket) do
    site = Repo.preload(assigns.site, [:team, :owners])

    has_access_to_revenue_goals? =
      Plausible.Billing.Feature.RevenueGoals.check_availability(site.team) == :ok

    form =
      (assigns.goal || %Plausible.Goal{})
      |> Plausible.Goal.changeset()
      |> to_form()

    form_type =
      if assigns.goal do
        case assigns.goal do
          %{page_path: p, scroll_threshold: s} when not is_nil(p) and s > -1 -> "scroll"
          %{page_path: p} when not is_nil(p) -> "pageviews"
          _ -> "custom_events"
        end
      else
        assigns[:goal_type] || "custom_events"
      end

    event_name_options_count = length(assigns.event_name_options)

    show_autoconfigure_modal? =
      case form_type do
        "custom_events" when event_name_options_count > 0 and is_nil(assigns.goal) ->
          true

        _ ->
          Map.get(socket.assigns, :show_autoconfigure_modal?, false)
      end

    socket =
      socket
      |> assign(
        id: assigns.id,
        context_unique_id: assigns.context_unique_id,
        form: form,
        event_name_options_count: event_name_options_count,
        event_name_options: Enum.map(assigns.event_name_options, &{&1, &1}),
        current_user: assigns.current_user,
        site_team: assigns.site_team,
        domain: assigns.domain,
        form_type: form_type,
        site: site,
        has_access_to_revenue_goals?: has_access_to_revenue_goals?,
        existing_goals: assigns.existing_goals,
        on_save_goal: assigns.on_save_goal,
        on_autoconfigure: assigns.on_autoconfigure,
        goal: assigns.goal,
        goal_type: assigns[:goal_type],
        show_autoconfigure_modal?: show_autoconfigure_modal?
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
      {if is_nil(@goal) && @show_autoconfigure_modal?, do: autoconfigure_modal(assigns)}
      {if is_nil(@goal) && not @show_autoconfigure_modal?, do: create_form(assigns)}
    </div>
    """
  end

  def edit_form(assigns) do
    ~H"""
    <.form :let={f} for={@form} phx-submit="save-goal" phx-target={@myself}>
      <.title>Edit goal for {@domain}</.title>

      <.custom_event_fields
        :if={@form_type == "custom_events"}
        f={f}
        suffix={@context_unique_id}
        current_user={@current_user}
        site_team={@site_team}
        site={@site}
        goal={@goal}
        existing_goals={@existing_goals}
        goal_options={@event_name_options}
        has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
        myself={@myself}
      />
      <.pageview_fields
        :if={@form_type == "pageviews"}
        f={f}
        goal={@goal}
        suffix={@context_unique_id}
        site={@site}
        myself={@myself}
      />
      <.scroll_fields
        :if={@form_type == "scroll"}
        f={f}
        goal={@goal}
        suffix={@context_unique_id}
        site={@site}
        myself={@myself}
      />

      <.button type="submit" class="w-full">
        Update goal
      </.button>
    </.form>
    """
  end

  def autoconfigure_modal(assigns) do
    ~H"""
    <div data-test-id="autoconfigure-modal">
      <.title>
        We detected {@event_name_options_count} custom {if @event_name_options_count == 1,
          do: "event",
          else: "events"}.
      </.title>

      <p class="mt-2 py-2 text-sm text-gray-600 dark:text-gray-400 text-pretty">
        These events have been sent from your site in the past 6 months but aren't yet configured as goals. Add them instantly or set one up manually.
      </p>

      <div class="flex justify-end gap-3">
        <.button
          theme="secondary"
          phx-click="add-manually"
          phx-target={@myself}
        >
          Add manually
        </.button>
        <.button
          phx-click="autoconfigure"
          phx-target={@myself}
        >
          <Heroicons.plus class="size-4" />
          Add {@event_name_options_count} {if @event_name_options_count == 1,
            do: "event",
            else: "events"}
        </.button>
      </div>
    </div>
    """
  end

  def create_form(assigns) do
    ~H"""
    <.form :let={f} for={@form} phx-submit="save-goal" phx-target={@myself}>
      <.title>
        Add goal for {Plausible.Sites.display_name(@site)}
      </.title>

      <.custom_event_fields
        :if={@form_type == "custom_events"}
        f={f}
        suffix={@context_unique_id}
        current_user={@current_user}
        site_team={@site_team}
        site={@site}
        existing_goals={@existing_goals}
        goal_options={@event_name_options}
        has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
        myself={@myself}
      />
      <.pageview_fields
        :if={@form_type == "pageviews"}
        f={f}
        suffix={@context_unique_id}
        site={@site}
        myself={@myself}
      />
      <.scroll_fields
        :if={@form_type == "scroll"}
        f={f}
        suffix={@context_unique_id}
        site={@site}
        myself={@myself}
      />

      <.button type="submit" class="w-full">
        Add goal
      </.button>
    </.form>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)
  attr(:suffix, :string)
  attr(:goal, Plausible.Goal, default: nil)
  attr(:myself, :any)
  attr(:rest, :global)

  def pageview_fields(assigns) do
    ~H"""
    <div
      id="pageviews-form"
      x-data="{ addCustomProperty: false }"
      class="py-2"
      {@rest}
    >
      <div class="text-sm pb-6 text-gray-600 dark:text-gray-400 text-pretty">
        Pageview goals allow you to measure how many people visit a specific page or section of your site.
        <.styled_link
          href="https://plausible.io/docs/pageview-goals"
          new_tab={true}
        >
          Learn more
        </.styled_link>
      </div>

      <.label for={"page_path_input_#{@suffix}"}>
        Page path
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
        label="Display name"
        id="pageview_display_name_input"
        field={@f[:display_name]}
        type="text"
        x-data="{ firstFocus: true }"
        x-on:focus="if (firstFocus) { $el.select(); firstFocus = false; }"
      />

      <.custom_property_section
        f={@f}
        suffix={@suffix}
        goal={@goal}
        myself={@myself}
        site={@site}
      />
    </div>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)
  attr(:suffix, :string)
  attr(:goal, Plausible.Goal, default: nil)
  attr(:myself, :any)
  attr(:rest, :global)

  def scroll_fields(assigns) do
    js =
      if is_nil(assigns.goal) do
        """
        {
          addCustomProperty: false,
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
          addCustomProperty: false,
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
      <div class="text-sm pb-6 text-gray-500 dark:text-gray-400 text-justify rounded-md">
        Scroll Depth goals allow you to see how many people scroll beyond your desired scroll depth percentage threshold.
        <.styled_link
          href="https://plausible.io/docs/scroll-depth"
          new_tab={true}
        >
          Learn more
        </.styled_link>
      </div>

      <.label for={"scroll_threshold_input_#{@suffix}"}>
        Scroll percentage threshold (1-100)
      </.label>

      <.input
        id={"scroll_threshold_input_#{@suffix}"}
        required
        field={@f[:scroll_threshold]}
        type="number"
        min="1"
        max="100"
        step="1"
        x-model="scrollThreshold"
        x-on:change="updateDisplayName"
      />

      <.label for={"scroll_page_path_input_#{@suffix}"} class="mt-3">
        Page path
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
        label="Display name"
        id="scroll_display_name_input"
        field={@f[:display_name]}
        type="text"
        x-model="displayName"
        x-data="{ firstFocus: true }"
        x-on:focus="if (firstFocus) { $el.select(); firstFocus = false; }"
      />

      <.custom_property_section
        f={@f}
        suffix={@suffix}
        goal={@goal}
        myself={@myself}
        site={@site}
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
  attr(:myself, :any)

  attr(:rest, :global)

  def custom_event_fields(assigns) do
    ~H"""
    <div
      id="custom-events-form"
      x-data="{ addCustomProperty: false }"
      class="py-2"
      {@rest}
    >
      <div id="event-fields">
        <div class="text-sm pb-6 text-gray-500 dark:text-gray-400 text-justify rounded-md">
          Custom Events are not tracked by default - you have to configure them on your site to be sent to Plausible. See examples and learn more in <.styled_link
            href="https://plausible.io/docs/custom-event-goals"
            new_tab={true}
          >
            our docs
          </.styled_link>.
        </div>

        <div>
          <.label for={"event_name_input_#{@suffix}"}>
            Event name
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
            label="Display name"
            id="custom_event_display_name_input"
            field={@f[:display_name]}
            type="text"
            x-data="{ firstFocus: true }"
            x-on:focus="if (firstFocus) { $el.select(); firstFocus = false; }"
          />
        </div>

        <.custom_property_section
          f={@f}
          suffix={@suffix}
          goal={@goal}
          myself={@myself}
          site={@site}
        />

        <%= if ee?() and Plausible.Sites.regular?(@site) and not editing_non_revenue_goal?(assigns) do %>
          <.revenue_goal_settings
            f={@f}
            site={@site}
            current_user={@current_user}
            site_team={@site_team}
            has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
            goal={@goal}
            suffix={@suffix}
          />
        <% else %>
          <div class="h-2"></div>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:suffix, :string, required: true)
  attr(:myself, :any, required: true)
  attr(:f, Phoenix.HTML.Form, required: true)
  attr(:goal, Plausible.Goal, default: nil)
  attr(:site, Plausible.Site, required: true)

  def custom_property_section(assigns) do
    has_custom_props? = Plausible.Goal.has_custom_props?(assigns[:goal])
    assigns = assign(assigns, :has_custom_props?, has_custom_props?)

    ~H"""
    <div :if={!@has_custom_props?} class="mt-6 mb-2 flex items-center justify-between">
      <span class="text-sm/6 font-medium text-gray-900 dark:text-gray-100">
        Add custom property
      </span>
      <.toggle_switch
        id="add-custom-property"
        id_suffix={@suffix}
        js_active_var="addCustomProperty"
      />
    </div>

    <div :if={@has_custom_props?} class="mt-6 mb-2 flex items-center justify-between">
      <span class="text-sm/6 font-medium text-gray-900 dark:text-gray-100">
        Custom properties
      </span>
    </div>

    <.error :for={msg <- Enum.map(@f[:custom_props].errors, &translate_error/1)}>
      {msg}
    </.error>

    <div class="space-y-3" x-show={if @has_custom_props?, do: "true", else: "addCustomProperty"}>
      <.live_component
        id={"property-pairs-#{@suffix}"}
        module={PlausibleWeb.Live.GoalSettings.PropertyPairs}
        site={@site}
        goal={@goal}
      />
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
    <div x-data={@js_data} data-test-id="revenue-goal-settings">
      <%= if is_nil(@goal) do %>
        <div class="mt-6 mb-2">
          <.revenue_toggle {assigns} />
        </div>
      <% else %>
        <label
          data-test-id="goal-currency-label"
          class="mt-4 mb-2 text-sm block font-medium dark:text-gray-100"
        >
          Currency
        </label>
      <% end %>
      <div class="mb-2" x-show="active" id={"revenue-input-#{@suffix}"}>
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

  def handle_event("save-goal", %{"goal" => goal_params}, %{assigns: %{goal: nil}} = socket) do
    {:ok, transformed_params} = transform_property_params(goal_params)

    case Plausible.Goals.create(socket.assigns.site, transformed_params) do
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
    {:ok, transformed_params} = transform_property_params(goal_params)

    case Plausible.Goals.update(goal, transformed_params) do
      {:ok, goal} ->
        socket = socket.assigns.on_save_goal.(goal, socket)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("autoconfigure", _params, socket) do
    socket = assign(socket, show_autoconfigure_modal?: false)
    {:noreply, socket.assigns.on_autoconfigure.(socket)}
  end

  def handle_event("add-manually", _params, socket) do
    {:noreply, assign(socket, show_autoconfigure_modal?: false)}
  end

  def suggest_page_paths(input, site) do
    query =
      QueryBuilder.build!(site,
        input_date_range: :all,
        metrics: [:pageviews],
        include: [imports: true]
      )

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

  on_ee do
    defp currency_option(nil), do: nil

    defp currency_option(goal) do
      Plausible.Goal.Revenue.revenue?(goal) &&
        Plausible.Goal.Revenue.currency_option(goal.currency)
    end
  else
    defp currency_option(_), do: nil
  end

  defp revenue_toggle(assigns) do
    ~H"""
    <.tooltip enabled?={not @has_access_to_revenue_goals?}>
      <:tooltip_content>
        <div class="text-xs">
          To get access to this feature
          <PlausibleWeb.Components.Billing.upgrade_call_to_action
            current_user={@current_user}
            current_team={@site_team}
          />.
        </div>
      </:tooltip_content>
      <div class="flex items-center justify-between">
        <span class={[
          "text-sm/6 font-medium",
          if(@has_access_to_revenue_goals?,
            do: "text-gray-900 dark:text-gray-100",
            else: "text-gray-500 dark:text-gray-400"
          )
        ]}>
          Enable revenue tracking
        </span>
        <PlausibleWeb.Components.Generic.toggle_switch
          id="enable-revenue-tracking"
          id_suffix={@suffix}
          js_active_var="active"
          disabled={not @has_access_to_revenue_goals?}
        />
      </div>
    </.tooltip>
    """
  end

  on_ee do
    defp editing_non_revenue_goal?(%{goal: nil} = _assigns), do: false

    defp editing_non_revenue_goal?(%{goal: goal} = _assigns) do
      not Plausible.Goal.Revenue.revenue?(goal)
    end
  else
    defp editing_non_revenue_goal?(_assigns), do: false
  end

  defp transform_property_params(
         %{"custom_props" => %{"keys" => prop_keys, "values" => prop_values}} = goal_params
       )
       when is_list(prop_keys) and is_list(prop_values) do
    transformed =
      goal_params
      |> Map.put(
        "custom_props",
        prop_keys
        |> Enum.zip(prop_values)
        |> Enum.reject(fn {k, v} -> String.trim(k) == "" and String.trim(v) == "" end)
        |> Enum.into(%{})
      )

    {:ok, transformed}
  end

  defp transform_property_params(goal_params) do
    {:ok, goal_params}
  end
end
