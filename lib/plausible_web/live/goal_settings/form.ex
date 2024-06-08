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

    form =
      %Plausible.Goal{}
      |> Plausible.Goal.changeset()
      |> to_form()

    socket =
      socket
      |> assign(
        id: assigns.id,
        suffix: assigns.suffix,
        form: form,
        event_name_options_count: length(assigns.event_name_options),
        current_user: assigns.current_user,
        domain: assigns.domain,
        selected_tab: "custom_events",
        site: site,
        has_access_to_revenue_goals?: has_access_to_revenue_goals?,
        existing_goals: assigns.existing_goals,
        on_save_goal: assigns.on_save_goal,
        on_autoconfigure: assigns.on_autoconfigure
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

        <h2 class="text-xl font-black dark:text-gray-100">Add Goal for <%= @domain %></h2>

        <.tabs selected_tab={@selected_tab} myself={@myself} />

        <.custom_event_fields
          :if={@selected_tab == "custom_events"}
          x-show="!tabSelectionInProgress"
          f={f}
          suffix={@suffix}
          current_user={@current_user}
          site={@site}
          existing_goals={@existing_goals}
          has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
          x-init="tabSelectionInProgress = false"
        />
        <.pageview_fields
          :if={@selected_tab == "pageviews"}
          x-show="!tabSelectionInProgress"
          f={f}
          suffix={@suffix}
          site={@site}
          x-init="tabSelectionInProgress = false"
        />

        <div class="py-4" x-show="!tabSelectionInProgress">
          <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
            Add Goal →
          </PlausibleWeb.Components.Generic.button>
        </div>

        <button
          :if={@selected_tab == "custom_events" && @event_name_options_count > 0}
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

  attr(:rest, :global)

  def pageview_fields(assigns) do
    ~H"""
    <div id="pageviews-form" class="py-2" {@rest}>
      <.label for="page_path_input">
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
        creatable
      />

      <.error :for={{msg, opts} <- @f[:page_path].errors}>
        <%= Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
        end) %>
      </.error>
    </div>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)
  attr(:current_user, Plausible.Auth.User)
  attr(:suffix, :string)
  attr(:existing_goals, :list)
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
            creatable
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
              if @has_access_to_revenue_goals? do
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
            disabled={not @has_access_to_revenue_goals?}
          >
            <span
              class="relative inline-flex h-6 w-11 flex-shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2"
              x-bind:class="active ? 'bg-indigo-600' : 'dark:bg-gray-700 bg-gray-200'"
            >
              <span
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
              id="enable-revenue-tracking"
            >
              Enable Revenue Tracking
            </span>
          </button>

          <div x-show="active">
            <.live_component
              id={"currency_input_#{@suffix}"}
              submit_name={@f[:currency].name}
              module={ComboBox}
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

        <.error :for={{msg, opts} <- @f[:event_name].errors}>
          <%= Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
          end) %>
        </.error>
      </div>
    </div>
    """
  end

  def tabs(assigns) do
    ~H"""
    <div class="mt-6 font-medium dark:text-gray-100">Goal Trigger</div>
    <div class="my-3 w-full flex rounded border border-gray-300 dark:border-gray-500">
      <.custom_events_tab selected?={@selected_tab == "custom_events"} myself={@myself} />
      <.pageviews_tab selected?={@selected_tab == "pageviews"} myself={@myself} />
    </div>
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
    {:noreply, assign(socket, selected_tab: tab, suffix: Plausible.RandomID.generate())}
  end

  def handle_event("save-goal", %{"goal" => goal}, socket) do
    case Plausible.Goals.create(socket.assigns.site, goal) do
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
end
