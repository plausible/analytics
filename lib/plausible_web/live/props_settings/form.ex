defmodule PlausibleWeb.Live.PropsSettings.Form do
  @moduledoc """
  Live view for the custom props creation form
  """
  use PlausibleWeb, :live_view
  import PlausibleWeb.Live.Components.Form
  alias PlausibleWeb.Live.Components.ComboBox

  def mount(
        _params,
        %{
          "site_id" => _site_id,
          "domain" => domain,
          "rendered_by" => pid
        },
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Plausible.Sites.get_for_user!(current_user, domain, [:owner, :admin, :super_admin])
      end)
      |> assign_new(:form, fn %{site: site} ->
        new_form(site)
      end)

    {:ok,
     assign(socket,
       domain: domain,
       rendered_by: pid,
       prop_key_options_count: 0
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
    <div class="fixed inset-0 flex items-center justify-center mt-16 z-50 overflow-y-auto overflow-x-hidden">
      <div class="w-1/2 h-full">
        <.form
          :let={f}
          for={@form}
          class="max-w-md w-full mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 pt-6 pb-8 mb-4 mt-8"
          phx-submit="allow-prop"
          phx-click-away="cancel-allow-prop"
        >
          <.title>Add Property for <%= @domain %></.title>

          <div class="mt-6">
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
              suggest_fun={
                pid = self()

                fn
                  "", [] ->
                    options =
                      @site
                      |> Plausible.Props.suggest_keys_to_allow()
                      |> Enum.map(&{&1, &1})

                    send(pid, {:update_prop_key_options_count, Enum.count(options)})

                    options

                  input, options ->
                    ComboBox.StaticSearch.suggest(input, options)
                end
              }
              creatable
            />

            <.error :for={{msg, opts} <- f[:allowed_event_props].errors}>
              <%= Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
              end) %>
            </.error>
          </div>

          <.button type="submit" class="w-full">
            Add Property →
          </.button>

          <button
            :if={@prop_key_options_count > 0}
            title="Use this to add any existing properties from your past events into your settings. This allows you to set up properties without having to manually enter each item."
            class="mt-4 text-sm hover:underline text-indigo-600 dark:text-indigo-400 text-left"
            phx-click="allow-existing-props"
          >
            Already sending custom properties? Click to add <%= @prop_key_options_count %> existing properties we found.
          </button>
        </.form>
      </div>
    </div>
    """
  end

  def handle_info({:update_prop_key_options_count, count}, socket) do
    {:noreply, assign(socket, prop_key_options_count: count)}
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
       form: new_form(site),
       prop_key_options_count: 0
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
