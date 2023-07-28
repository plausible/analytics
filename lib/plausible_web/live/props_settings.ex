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

    site =
      if Plausible.Auth.is_super_admin?(user_id) do
        Plausible.Sites.get_by_domain(domain)
      else
        Plausible.Sites.get_for_user!(user_id, domain, [:owner, :admin])
      end

    suggestions =
      site
      |> Plausible.Props.suggest_keys_to_allow()
      |> Enum.map(&{&1, &1})

    {:ok,
     assign(socket,
       site: site,
       current_user_id: user_id,
       form: new_form(site),
       suggestions: suggestions
     )}
  end

  def render(assigns) do
    ~H"""
    <section id="props-settings-main">
      <.live_component id="embedded_liveview_flash" module={PlausibleWeb.Live.Flash} flash={@flash} />

      <h1 class="text-normal leading-6 font-medium text-gray-900 dark:text-gray-100">
        Configured properties
      </h1>

      <h2 class="mt-1 text-sm leading-5 text-gray-500 dark:text-gray-400">
        In order for the properties to show up on your dashboard, you need to
        explicitly add them below first
      </h2>

      <.form :let={f} for={@form} id="props-form" phx-submit="allow" class="mt-5">
        <div class="flex space-x-2">
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
        </div>

        <div :if={length(f[:allowed_event_props].errors) > 0} id="prop-errors" role="alert">
          <%= PlausibleWeb.ErrorHelpers.error_tag(f, :allowed_event_props) %>
        </div>
      </.form>

      <button
        :if={length(@suggestions) > 0}
        title="Use this to add any existing properties from your past events into your settings. This allows you to set up properties without having to manually enter each item."
        class="mt-1 text-sm hover:underline text-indigo-600 dark:text-indigo-400"
        phx-click="allow-existing-props"
      >
        Already sending custom properties? Click to add all existing properties
      </button>

      <div class="mt-5">
        <%= if is_list(@site.allowed_event_props) && length(@site.allowed_event_props) > 0 do %>
          <ul id="allowed-props" class="divide-gray-200 divide-y dark:divide-gray-600">
            <li
              :for={{prop, index} <- Enum.with_index(@site.allowed_event_props)}
              id={"prop-#{index}"}
              class="flex py-4"
            >
              <span class="flex-1 truncate font-medium text-sm text-gray-800 dark:text-gray-200">
                <%= prop %>
              </span>
              <button
                data-confirm={"Are you sure you want to remove property '#{prop}'? This will just affect the UI, all of your analytics data will stay intact."}
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
    </section>
    """
  end

  def handle_event("allow", %{"prop" => prop}, socket) do
    case Plausible.Props.allow(socket.assigns.site, prop) do
      {:ok, site} ->
        send_update(ComboBox, id: :prop_input, display_value: "", submit_value: "")

        {:noreply,
         assign(socket,
           site: site,
           form: new_form(site),
           suggestions: rebuild_suggestions(socket.assigns.suggestions, site.allowed_event_props)
         )}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end

  def handle_event("disallow", %{"prop" => prop}, socket) do
    {:ok, site} = Plausible.Props.disallow(socket.assigns.site, prop)
    {:noreply, assign(socket, site: site)}
  end

  def handle_event("allow-existing-props", _params, socket) do
    {:ok, site} = Plausible.Props.allow_existing_props(socket.assigns.site)

    {:noreply,
     assign(socket,
       site: site,
       suggestions: rebuild_suggestions(socket.assigns.suggestions, site.allowed_event_props)
     )}
  end

  defp rebuild_suggestions(suggestions, allowed_event_props) do
    allowed_event_props = allowed_event_props || []

    suggestions =
      for {suggestion, _} <- suggestions,
          suggestion not in allowed_event_props,
          do: {suggestion, suggestion}

    send_update(ComboBox, id: :prop_input, suggestions: suggestions)
    suggestions
  end

  defp new_form(site) do
    to_form(Plausible.Props.allow_changeset(site, []))
  end
end
