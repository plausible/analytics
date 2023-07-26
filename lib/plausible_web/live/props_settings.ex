defmodule PlausibleWeb.Live.PropsSettings do
  @moduledoc """
  LiveView allowing listing, allowing and disallowing custom event properties.
  """

  use Phoenix.LiveView
  use Phoenix.HTML
  alias PlausibleWeb.Live.Components.ComboBox

  def mount(
        _params,
        %{"site_id" => _site_id, "domain" => domain, "current_user_id" => user_id},
        socket
      ) do
    true = Plausible.Props.enabled_for?(%Plausible.Auth.User{id: user_id})
    site = get_site(user_id, domain)
    allowed_event_props = site.allowed_event_props || []

    suggestions =
      site
      |> Plausible.Props.suggest_keys_to_allow()
      |> Enum.map(&{&1, &1})

    {:ok,
     assign(socket,
       site_id: site.id,
       domain: site.domain,
       current_user_id: user_id,
       allowed_event_props: allowed_event_props,
       suggestions: suggestions
     )}
  end

  def render(assigns) do
    ~H"""
    <div id="props-settings-main">
      <.live_component id="embedded_liveview_flash" module={PlausibleWeb.Live.Flash} flash={@flash} />

      <form id="props-form" phx-submit="allow" class="flex space-x-2">
        <.live_component
          id={:prop_input}
          submit_name="prop"
          class="flex-1"
          module={ComboBox}
          suggest_mod={ComboBox.StaticSearch}
          options={@suggestions}
          required
          creatable
        />

        <button id="allow" type="submit" class="button">+ Add</button>
      </form>

      <button
        :if={length(@suggestions) > 0}
        title="Use this to import any existing properties from your past events into your settings. This allows you to set up properties without having to manually enter each item."
        class="mt-1 text-sm hover:underline text-indigo-600 dark:text-indigo-400"
        phx-click="auto-import"
      >
        Or auto-import properties from your events
      </button>

      <div class="mt-3">
        <%= if is_list(@allowed_event_props) && length(@allowed_event_props) > 0 do %>
          <ul id="allowed-props" class="divide-gray-200 divide-y dark:divide-gray-600">
            <li
              :for={{prop, index} <- Enum.with_index(@allowed_event_props)}
              id={"prop-#{index}"}
              class="flex py-4"
            >
              <span class="flex-1 truncate font-medium text-sm text-gray-800 dark:text-gray-200">
                <%= prop %>
              </span>
              <button
                phx-click="disallow"
                phx-value-prop={prop}
                class="w-4 h-4 text-red-600 hover:text-red-700"
                aria-label={"Remove #{prop} property"}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  aria-hidden="true"
                  focusable="false"
                >
                  <polyline points="3 6 5 6 21 6"></polyline>
                  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2">
                  </path>
                  <line x1="10" y1="11" x2="10" y2="17"></line>
                  <line x1="14" y1="11" x2="14" y2="17"></line>
                </svg>
              </button>
            </li>
          </ul>
        <% else %>
          <p class="text-sm text-gray-800 dark:text-gray-200">
            No properties configured for this site yet
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("allow", %{"prop" => prop}, socket) do
    {:ok, site} =
      socket.assigns.current_user_id
      |> get_site(socket.assigns.domain)
      |> Plausible.Props.allow(prop)

    send_update(ComboBox, id: :prop_input, display_value: "", submit_value: "")

    socket =
      socket
      |> assign(allowed_event_props: site.allowed_event_props)
      |> rebuild_suggestions()

    {:noreply, socket}
  end

  def handle_event("disallow", %{"prop" => prop}, socket) do
    {:ok, site} =
      socket.assigns.current_user_id
      |> get_site(socket.assigns.domain)
      |> Plausible.Props.disallow(prop)

    {:noreply, assign(socket, allowed_event_props: site.allowed_event_props)}
  end

  def handle_event("auto-import", _params, socket) do
    {:ok, site} =
      socket.assigns.current_user_id
      |> get_site(socket.assigns.domain)
      |> Plausible.Props.auto_import()

    socket =
      socket
      |> assign(allowed_event_props: site.allowed_event_props)
      |> rebuild_suggestions()

    {:noreply, socket}
  end

  defp get_site(user_id, domain) do
    if Plausible.Auth.is_super_admin?(user_id) do
      Plausible.Sites.get_by_domain(domain)
    else
      Plausible.Sites.get_for_user!(user_id, domain, [:owner, :admin])
    end
  end

  defp rebuild_suggestions(socket) do
    suggestions =
      for {suggestion, _} <- socket.assigns.suggestions,
          suggestion not in socket.assigns.allowed_event_props,
          do: {suggestion, suggestion}

    send_update(ComboBox, id: :prop_input, suggestions: suggestions)
    assign(socket, suggestions: suggestions)
  end
end
