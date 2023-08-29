defmodule PlausibleWeb.Live.PropsSettings.Form do
  @moduledoc """
  Live view for the custom props creation form
  """
  use Phoenix.LiveView
  import PlausibleWeb.Live.Components.Form
  alias PlausibleWeb.Live.Components.ComboBox

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
    true = Plausible.Props.enabled_for?(%Plausible.Auth.User{id: user_id})

    site =
      if Plausible.Auth.is_super_admin?(user_id) do
        Plausible.Sites.get_by_domain(domain)
      else
        Plausible.Sites.get_for_user!(user_id, domain, [:owner, :admin])
      end

    form = new_form(site)

    initial_suggestions =
      site
      |> Plausible.Props.suggest_keys_to_allow()
      |> Enum.map(&{&1, &1})

    {:ok,
     assign(socket,
       form: form,
       suggestions: initial_suggestions,
       domain: domain,
       rendered_by: pid,
       site: site
     )}
  end

  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50"
      phx-window-keydown="cancel-allow-prop"
      phx-key="Escape"
    >
    </div>
    <div class="fixed inset-0 flex items-center justify-center mt-32 z-50">
      <div class="w-1/2 h-full">
        <.form
          :let={f}
          for={@form}
          class="max-w-md w-full mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 pt-6 pb-8 mb-4 mt-8"
          phx-submit="allow-prop"
          phx-click-away="cancel-allow-prop"
        >
          <h2 class="text-xl font-black dark:text-gray-100">Add property for <%= @domain %></h2>

          <div class="py-2">
            <.label for="prop_input">
              Property
            </.label>

            <.live_component
              id="prop_input"
              submit_name="prop"
              class={[
                "py-2"
              ]}
              module={ComboBox}
              options={@suggestions}
              suggest_fun={&ComboBox.StaticSearch.suggest/2}
              creatable
            />

            <.error :for={{msg, opts} <- f[:allowed_event_props].errors}>
              <%= Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
              end) %>
            </.error>
          </div>

          <div class="py-4">
            <button type="submit" class="button text-base font-bold w-full">
              Add property →
            </button>
          </div>

          <button
            :if={length(@suggestions) > 0}
            title="Use this to add any existing properties from your past events into your settings. This allows you to set up properties without having to manually enter each item."
            class="mt-2 text-sm hover:underline text-indigo-600 dark:text-indigo-400 text-left"
            phx-click="allow-existing-props"
          >
            Already sending custom properties? Click to add all existing properties.
          </button>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("allow-prop", %{"prop" => prop}, socket) do
    case Plausible.Props.allow(socket.assigns.site, prop) do
      {:ok, site} ->
        send(socket.assigns.rendered_by, {:prop_allowed, prop})

        {:noreply,
         assign(socket,
           site: site,
           form: new_form(site)
         )}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end

  def handle_event("allow-existing-props", _params, socket) do
    {:ok, site} = Plausible.Props.allow_existing_props(socket.assigns.site)
    send(socket.assigns.rendered_by, {:props_allowed, site.allowed_event_props})

    {:noreply,
     assign(socket,
       site: site,
       form: new_form(site)
     )}
  end

  def handle_event("cancel-allow-prop", _value, socket) do
    send(socket.assigns.rendered_by, :cancel_add_prop)
    {:noreply, socket}
  end

  defp new_form(site) do
    to_form(Plausible.Props.allow_changeset(site, []))
  end
end
