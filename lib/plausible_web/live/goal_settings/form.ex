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
        form: form,
        current_user: assigns.current_user,
        domain: assigns.domain,
        selected_tab: "custom_events",
        site: site,
        has_access_to_revenue_goals?: has_access_to_revenue_goals?,
        on_save_goal: assigns.on_save_goal
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
          current_user={@current_user}
          site={@site}
          has_access_to_revenue_goals?={@has_access_to_revenue_goals?}
          x-init="tabSelectionInProgress = false"
        />
        <.pageview_fields
          :if={@selected_tab == "pageviews"}
          x-show="!tabSelectionInProgress"
          f={f}
          site={@site}
          x-init="tabSelectionInProgress = false"
        />

        <div class="py-4" x-show="!tabSelectionInProgress">
          <PlausibleWeb.Components.Generic.button type="submit" class="w-full">
            Add Goal →
          </PlausibleWeb.Components.Generic.button>
        </div>
      </.form>
    </div>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)

  attr(:rest, :global)

  def pageview_fields(assigns) do
    ~H"""
    <div id="pageviews-form" class="py-2" {@rest}>
      <.label for="page_path_input">
        Page Path
      </.label>

      <.live_component
        id="page_path_input"
        submit_name="goal[page_path]"
        class={[
          "py-2"
        ]}
        module={ComboBox}
        suggest_fun={fn input, options -> suggest_page_paths(input, options, @site) end}
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
          <.input
            autofocus
            field={@f[:event_name]}
            label="Event Name"
            class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500 w-full p-2 mt-2"
            placeholder="e.g. Signup"
            autocomplete="off"
          />
        </div>

        <div
          :if={full_build?()}
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
              id="currency_input"
              submit_name={@f[:currency].name}
              module={ComboBox}
              suggest_fun={
                on_full_build do
                  fn
                    "", [] ->
                      Plausible.Goal.Revenue.currency_options()

                    input, options ->
                      ComboBox.StaticSearch.suggest(input, options, weight_threshold: 0.8)
                  end
                end
              }
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
      x-on:click="tabSelectionInProgress = true"
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
      x-on:click="tabSelectionInProgress = true"
      phx-click="switch-tab"
      phx-value-tab="pageviews"
      phx-target={@myself}
    >
      Pageview
    </a>
    """
  end

  def handle_event("switch-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, selected_tab: tab)}
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

  def suggest_page_paths(input, _options, site) do
    query = Plausible.Stats.Query.from(site, %{})

    site
    |> Plausible.Stats.filter_suggestions(query, "page", input)
    |> Enum.map(fn %{label: label, value: value} -> {label, value} end)
  end
end
