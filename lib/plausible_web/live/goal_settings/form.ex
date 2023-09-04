defmodule PlausibleWeb.Live.GoalSettings.Form do
  @moduledoc """
  Live view for the goal creation form
  """
  use Phoenix.LiveView
  import PlausibleWeb.Live.Components.Form
  alias PlausibleWeb.Live.Components.ComboBox

  alias Plausible.Repo

  def mount(
        _params,
        %{
          "site_id" => _site_id,
          "current_user_id" => user_id,
          "domain" => domain,
          "rendered_by" => pid
        },
        socket
      ) do
    form = to_form(Plausible.Goal.changeset(%Plausible.Goal{}))

    site = Plausible.Sites.get_for_user!(user_id, domain, [:owner, :admin, :super_admin])

    {:ok,
     assign(socket,
       current_user: Repo.get(Plausible.Auth.User, user_id),
       form: form,
       domain: domain,
       rendered_by: pid,
       tabs: %{custom_events: true, pageviews: false},
       site: site
     )}
  end

  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50"
      phx-window-keydown="cancel-add-goal"
      phx-key="Escape"
    >
    </div>
    <div class="fixed inset-0 flex items-center justify-center mt-16 z-50 overflow-y-auto overflow-x-hidden">
      <div class="w-1/2 h-full">
        <.form
          :let={f}
          for={@form}
          class="max-w-md w-full mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 pt-6 pb-8 mb-4 mt-8"
          phx-submit="save-goal"
          phx-click-away="cancel-add-goal"
        >
          <h2 class="text-xl font-black dark:text-gray-100">Add goal for <%= @domain %></h2>

          <.tabs tabs={@tabs} />

          <.custom_event_fields :if={@tabs.custom_events} f={f} />
          <.pageview_fields :if={@tabs.pageviews} f={f} site={@site} />

          <div class="py-4">
            <button type="submit" class="button text-base font-bold w-full">
              Add goal →
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr(:f, Phoenix.HTML.Form)
  attr(:site, Plausible.Site)

  def pageview_fields(assigns) do
    ~H"""
    <div class="py-2">
      <.label for="page_path_input">
        Page path
      </.label>

      <.live_component
        id="page_path_input"
        submit_name="goal[page_path]"
        class={[
          "py-2"
        ]}
        module={ComboBox}
        suggest_fun={fn input, options -> suggest_page_paths(input, options, @site) end}
        async={true}
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

  def custom_event_fields(assigns) do
    ~H"""
    <div class="my-6">
      <div id="event-fields">
        <div class="pb-6 text-xs text-gray-700 dark:text-gray-200 text-justify rounded-md">
          Custom events are not tracked by default - you have to configure them on your site to be sent to Plausible. See examples and learn more in <a
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
            label="Event name"
            class="focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-900 dark:text-gray-300 block w-7/12 rounded-md sm:text-sm border-gray-300 dark:border-gray-500 w-full p-2 mt-2"
            placeholder="e.g. Signup"
            autocomplete="off"
          />
        </div>

        <div
          class="mt-6 space-y-3"
          x-data={
            Jason.encode!(%{
              active: !!@f[:currency].value and @f[:currency].value != "",
              currency: @f[:currency].value
            })
          }
        >
          <div
            class="flex items-center w-max cursor-pointer"
            x-on:click="active = !active; currency = ''"
          >
            <button
              class="relative inline-flex h-6 w-11 flex-shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2"
              x-bind:class="active ? 'bg-indigo-600' : 'dark:bg-gray-700 bg-gray-200'"
              x-bind:aria-checked="active"
              aria-labelledby="enable-revenue-tracking"
              role="switch"
              type="button"
            >
              <span
                aria-hidden="true"
                class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
                x-bind:class="active ? 'dark:bg-gray-800 translate-x-5' : 'dark:bg-gray-800 translate-x-0'"
              />
            </button>
            <span
              class="ml-3 font-medium text-gray-900 dark:text-gray-200"
              id="enable-revenue-tracking"
            >
              Enable revenue tracking
            </span>
          </div>

          <div class="rounded-md bg-yellow-50 dark:bg-yellow-900 p-4" x-show="active">
            <p class="text-xs text-yellow-700 dark:text-yellow-50 text-justify">
              Revenue tracking is an upcoming premium feature that's free-to-use
              during the private preview. Pricing will be announced soon. See
              examples and learn more in <a
                class="font-medium text-yellow underline hover:text-yellow-600"
                href="https://plausible.io/docs/ecommerce-revenue-tracking"
              >our docs</a>.
            </p>
          </div>

          <div x-show="active">
            <.live_component
              id="currency_input"
              submit_name={@f[:currency].name}
              module={ComboBox}
              suggest_fun={
                fn
                  "", [] ->
                    Plausible.Goal.currency_options()

                  input, options ->
                    ComboBox.StaticSearch.suggest(input, options, weight_threshold: 0.8)
                end
              }
              async={true}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def tabs(assigns) do
    ~H"""
    <div class="mt-6 font-medium dark:text-gray-100">Goal trigger</div>
    <div class="my-3 w-full flex rounded border border-gray-300 dark:border-gray-500">
      <.custom_events_tab tabs={@tabs} />
      <.pageviews_tab tabs={@tabs} />
    </div>
    """
  end

  defp custom_events_tab(assigns) do
    ~H"""
    <a
      class={[
        "w-1/2 text-center py-2 border-r dark:border-gray-500",
        "cursor-pointer",
        @tabs.custom_events && "shadow-inner font-bold bg-indigo-600 text-white",
        !@tabs.custom_events && "dark:text-gray-100 text-gray-800"
      ]}
      id="event-tab"
      phx-click="switch-tab"
    >
      Custom event
    </a>
    """
  end

  def pageviews_tab(assigns) do
    ~H"""
    <a
      class={[
        "w-1/2 text-center py-2 cursor-pointer",
        @tabs.pageviews && "shadow-inner font-bold bg-indigo-600 text-white",
        !@tabs.pageviews && "dark:text-gray-100 text-gray-800"
      ]}
      id="pageview-tab"
      phx-click="switch-tab"
    >
      Pageview
    </a>
    """
  end

  def handle_event("switch-tab", _params, socket) do
    {:noreply,
     assign(socket,
       tabs: %{
         custom_events: !socket.assigns.tabs.custom_events,
         pageviews: !socket.assigns.tabs.pageviews
       }
     )}
  end

  def handle_event("save-goal", %{"goal" => goal}, socket) do
    case Plausible.Goals.create(socket.assigns.site, goal) do
      {:ok, goal} ->
        send(socket.assigns.rendered_by, {:goal_added, Map.put(goal, :funnels, [])})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("cancel-add-goal", _value, socket) do
    send(socket.assigns.rendered_by, :cancel_add_goal)
    {:noreply, socket}
  end

  def suggest_page_paths(input, _options, site) do
    query = Plausible.Stats.Query.from(site, %{})

    site
    |> Plausible.Stats.filter_suggestions(query, "page", input)
    |> Enum.map(fn %{label: label, value: value} -> {label, value} end)
  end
end
